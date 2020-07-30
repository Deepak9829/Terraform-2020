provider "aws" {
  region     = "ap-south-1"
  profile    = "deepak"
}


resource "aws_security_group" "mysecurity" {
  name        = "bhaiji"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-50f2ef38"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysecurity"
  }
}

resource "aws_instance" "web2" {
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name = "key777"
  security_groups = [ "bhaiji" ]

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/key/key777.pem")
    host     = aws_instance.web2.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git EOF -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo yum install nfs-utils -y",
     // "sudo yum install amazon-efs-utils -y",

    ]
  }


 tags = {
    Name = "lwos"
  }

depends_on = [
    aws_security_group.mysecurity,
  ]
}

output "deepu" {
  value = aws_instance.web2.availability_zone
}

resource "aws_efs_file_system" "efs_volume" {
 creation_token = "efs"
 depends_on=[aws_security_group.mysecurity,
 aws_instance.web2]
 tags = {
 Name = "efs_volume"
 }
}


resource "aws_efs_mount_target" "mount" {
depends_on =[aws_efs_file_system.efs_volume]
file_system_id = aws_efs_file_system.efs_volume.id
subnet_id =aws_instance.web2.subnet_id
security_groups= ["${aws_security_group.mysecurity.id}"]
}


resource "null_resource" "null_volume_attach" {
depends_on =[ aws_efs_mount_target.mount,
aws_efs_file_system.efs_volume, aws_instance.web2 ]

connection {
type = "ssh"
user = "ec2-user"
private_key = file("C:/key/key777.pem")
port = 22
host = aws_instance.web2.public_ip
}
provisioner "remote-exec" {
inline = [
"sudo mount  ${aws_efs_file_system.efs_volume.dns_name}:/  /var/www/html",
      "sudo echo ${aws_efs_file_system.efs_volume.dns_name}:/ /var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Kapilmundra/DeployCode-AWSCloud.git /var/www/html/"
]
}
}




output "myip"{
    value = aws_instance.web2.public_ip
}


resource "aws_s3_bucket" "bc" {
  depends_on = [ null_resource.null_volume_attach ]
  bucket = "myim456598"
  force_destroy = true
  acl    = "public-read"
 }

output "s3info" {
value = aws_s3_bucket.bc
}


resource "null_resource" "nulllocal3"{
provisioner "local-exec" {
        command     = "git clone  https://github.com/Deepaksaini7737/IMAGES.git   images_m"
    }
provisioner "local-exec" {
        when        =   destroy
        command     =   "echo Y | rmdir /s images_m"
    }
}


resource "aws_s3_bucket_object" "image-upload" {
    bucket  = aws_s3_bucket.bc.bucket
    key     = "p1.jpeg"
    source  = "images_m/p1.jpeg"
    acl     = "public-read"

depends_on = [
    aws_s3_bucket.bc,
  ]
}



variable "var1" {default = "S3-"}
locals {
    s3_origin_id = "${var.var1}${aws_s3_bucket.bc.bucket}"
    image_url = "${aws_cloudfront_distribution.s3_distribution.domain_name}  /${aws_s3_bucket_object.image-upload.key}"
}
resource "aws_cloudfront_distribution" "s3_distribution" {


  origin {
         domain_name = aws_s3_bucket.bc.bucket_regional_domain_name
         origin_id   = local.s3_origin_id
  
 custom_origin_config {

         http_port = 80
         https_port = 80
         origin_protocol_policy = "match-viewer"
         origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
      }
    default_cache_behavior {
        allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods   = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id
        forwarded_values {
            query_string = false
            cookies {
                forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
         min_ttl                = 0
          default_ttl            = 3600
          max_ttl                = 86400

    }
enabled             = true

restrictions {
        geo_restriction {
        restriction_type = "none"
        }
    }


viewer_certificate {
        cloudfront_default_certificate = true
    }
connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.web2.public_ip
        port    = 22
        private_key = file("C:/key/key777.pem")
    }
provisioner "remote-exec" {
        inline  = [
            "sudo su << \"EOF\" \n echo \"<img src='${self.domain_name}'>\" >> /var/www/html/photos.html \n \"EOF\"",
            "sudo su << EOF",
            "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.image-upload.key}'>\" >> /var/www/html/photos.html",
            "EOF"
        ]
    }
depends_on = [
    aws_s3_bucket_object.image-upload,
  ]

}

output "deepu1" {
  value = aws_cloudfront_distribution.s3_distribution
}
