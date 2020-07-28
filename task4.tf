provider "aws" {
  region     = "ap-south-1"
  profile    = "deepak"
}


resource "aws_vpc" "myvpc" {
cidr_block = "10.0.0.0/16"
instance_tenancy = "default"
enable_dns_hostnames = true

tags = {
Name = "Task4-VPC"
}

}

output "vpc_id" {
value = aws_vpc.myvpc.id
}

resource "aws_subnet" "public" {

depends_on = [ aws_vpc.myvpc ]
vpc_id = aws_vpc.myvpc.id
cidr_block = "10.0.1.0/24"
map_public_ip_on_launch = true
availability_zone = "ap-south-1a"
tags = {
Name = "subnet-1"
}

}

output "aws_subnet_public" {
value = aws_subnet.public.id
}


# aws subnets of our vpc

resource "aws_subnet" "private" {
depends_on = [ aws_vpc.myvpc ]
vpc_id = aws_vpc.myvpc.id
cidr_block = "10.0.2.0/24"
map_public_ip_on_launch = true
availability_zone = "ap-south-1b"
tags = {
Name = "subnet-2"
}
}

output "aws_subnet_private" {
value = aws_subnet.private.id
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id
  depends_on = [aws_vpc.myvpc,aws_subnet.public,aws_subnet.private]

  tags = {
    Name = "my_in_gw"
  }
}

resource "aws_route_table" "myroutetable1" {
depends_on = [aws_internet_gateway.gw]
vpc_id = aws_vpc.myvpc.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.gw.id
}
tags = {
Name = "Myroutetable1"
}
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.myroutetable1.id
}

resource "aws_eip" "lb" {
  vpc      = true
}


resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.gw]
}

resource "aws_route_table" "nat-table" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }
  tags = {
    Name = "main-1b"
  }
}


resource "aws_route_table_association" "nat-b" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.nat-table.id
}



resource "aws_security_group" "sg1" {
depends_on = [aws_vpc.myvpc]
name        = "my wordpress security"
description = "Allow http ssh mysqlport"
vpc_id      = aws_vpc.myvpc.id
ingress {
description = "allow http"
from_port   = 80
to_port     = 80
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
description = "allow SSH"
from_port   = 22
to_port     = 22
protocol    = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
description = "allow mysql port"
from_port   = 3306
to_port     = 3306
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
Name = "wordpress_sg"
}
}



resource "aws_security_group" "sg2" {
depends_on = [aws_vpc.myvpc]
name        = "my mysql security"
description = "Allow mysqlport"
vpc_id      = aws_vpc.myvpc.id
ingress {
description = "allow mysql port"
from_port   = 3306
to_port     = 3306
protocol    = "tcp"
security_groups = [ aws_security_group.sg1.id ]
}
egress {
from_port   = 0
to_port     = 0
protocol    = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
Name = "mysql_sg"
}
}

resource "aws_security_group" "bastion_sg" {


 depends_on = [ aws_vpc.myvpc, ]
  name        = "bastion_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.myvpc.id


  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
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
    Name = "bastion"
  }
}


resource "aws_instance" "wordpress" {

ami           = "ami-7e257211"
instance_type = "t2.micro"
subnet_id = aws_subnet.public.id
vpc_security_group_ids = [ aws_security_group.sg1.id ]
key_name = "key777"
tags = {
Name = "Wordpress"
}
}

output  "ip1" {
value = aws_instance.wordpress.public_ip
}

resource "aws_instance" "baston" {
 depends_on = [ aws_vpc.myvpc,
                  aws_subnet.public,
                  aws_security_group.bastion_sg, ]
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name = "key777"
  vpc_security_group_ids = [ aws_security_group.bastion_sg.id]
  subnet_id = aws_subnet.public.id
 tags = {
    Name = "Baseton_OS"
  }
}



resource "aws_instance" "mysql" {

ami           = "ami-76166b19"
instance_type = "t2.micro"
subnet_id = aws_subnet.private.id
vpc_security_group_ids = [ aws_security_group.sg2.id ]
key_name = "key777"
tags = {
Name = "mysql"
}
}



output  "ip2" {
value = aws_instance.mysql.public_ip
}
