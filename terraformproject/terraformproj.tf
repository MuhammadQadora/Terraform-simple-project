terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

##### Credintials are provided using AWSCLI


### VPC and Network resources

resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "myvpc"
  }
}

#### INTERNET GATEWAY
resource "aws_internet_gateway" "myvpcIGW" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myvpcIGW"
  }
}

####### ROUTE TABLE
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myvpcIGW.id
  }


  tags = {
    Name = "public"
  }
}


#### subnet
resource "aws_subnet" "public-subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-west-2a"


  tags = {
    Name = "public-subnet"
  }
}

#### Associate subnet to route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public.id
}

#### Security to allow ssh on port 22, http port 80 ,https 443:

resource "aws_security_group" "webserver-SG" {
  name        = "web-server-SG"
  description = "allow ssh,http,and https connection"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "TLS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow http internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow-web"
  }
}

#### Network interface

resource "aws_network_interface" "web-nic" {
  subnet_id       = aws_subnet.public-subnet.id
  private_ips     = ["10.0.0.15"]
  security_groups = [aws_security_group.webserver-SG.id]
}

##### AWS ElasticiP

resource "aws_eip" "eip" {
  vpc               = true
  network_interface = aws_network_interface.web-nic.id
  depends_on = [
    aws_internet_gateway.myvpcIGW,
    aws_instance.name
  ]
}

######### EC2 instance

resource "aws_instance" "name" {
  ami               = "ami-017fecd1353bcc96e"
  instance_type     = "t2.micro"
  availability_zone = "us-west-2a"
  key_name      = "vockey"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-nic.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt -y update
    sudo apt -y install apache2
    sudo systemctl start apache2
    sudo bash -c 'echo "welcome to my first terraform project " > /var/www/html/index.html'
    EOF
    tags = {
      "Name" = "webserver"
    }
}