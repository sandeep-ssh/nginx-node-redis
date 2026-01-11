provider "aws" {
  region = "us-east-1"
}

#######################
# VPC + Subnet
#######################

resource "aws_vpc" "web_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "web-vpc"
  }
}

resource "aws_subnet" "web_subnet" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "web-subnet"
  }
}

resource "aws_internet_gateway" "web_igw" {
  vpc_id = aws_vpc.web_vpc.id

  tags = {
    Name = "web-igw"
  }
}

resource "aws_route_table" "web_route" {
  vpc_id = aws_vpc.web_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web_igw.id
  }

  tags = {
    Name = "web-route"
  }
}

resource "aws_route_table_association" "web_assoc" {
  subnet_id      = aws_subnet.web_subnet.id
  route_table_id = aws_route_table.web_route.id
}

#######################
# Security Group
#######################

resource "aws_security_group" "web_sg" {
  name        = "nginx-web-sg"
  description = "Allow HTTP & SSH"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
    Name = "nginx-web-sg"
  }
}

#######################
# EC2 Instance
#######################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io docker-compose git
              systemctl start docker
              systemctl enable docker
              git clone https://github.com/sandeep-ssh/nginx-node-redis.git 
              cd nginx-node-redis/
              docker-compose up -d --build
              EOF

  tags = {
    Name = "nginx-docker-instance"
  }
}

#######################
# Output
#######################

output "public_ip" {
  value = aws_instance.web.public_ip
}