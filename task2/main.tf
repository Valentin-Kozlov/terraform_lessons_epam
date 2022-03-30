terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8.0"
    }
  }
  required_version = ">= 1.1.7"
}

#-----------------------------------------------------------------------

provider "aws" {
  region     = var.region_name
}

#-----------------------------------------------------------------------

data "aws_ami" "latest-ubuntu-ami" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

#-----------------------------------------------------------------------

data "aws_availability_zones" "zones" {}

#----------------------------------------------------------------------#
#                        VPC and subnets                               #
#----------------------------------------------------------------------#

resource "aws_vpc" "vpc_for_web" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.common_tags, { Name = "WEB-VPC" })
}

#----------------------------------------------------------------------

resource "aws_subnet" "web-sub-private" {
  count             = length(var.subnets-private)
  vpc_id            = aws_vpc.vpc_for_web.id
  cidr_block        = var.subnets-private[count.index]
  availability_zone = var.availability_zones[count.index]
  tags              = merge(var.common_tags, { Name = "WEB-SUB-Private" })
}

#----------------------------------------------------------------------

resource "aws_subnet" "web-sub-public" {
  count                   = length(var.subnets-public)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.vpc_for_web.id
  cidr_block              = var.subnets-public[count.index]
  availability_zone       = var.availability_zones[count.index]
  tags                    = merge(var.common_tags, { Name = "WEB-SUB-Public" })
}

#----------------------------------------------------------------------

resource "aws_internet_gateway" "public-ig" {
  vpc_id = aws_vpc.vpc_for_web.id
}

#----------------------------------------------------------------------

resource "aws_default_route_table" "public" {
  default_route_table_id = aws_vpc.vpc_for_web.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public-ig.id
  }
}

#----------------------------------------------------------------------#
#                        Security Groups                               #
#----------------------------------------------------------------------#

resource "aws_security_group" "web-ubuntu-ec2" {
  name        = "WebServer-from-Terraform-deploy-SG-EC2"
  description = "Allow for EC2 inbound traffic"
  vpc_id      = aws_vpc.vpc_for_web.id

  dynamic "ingress" {
    for_each = var.inbound_ports_EC2
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = merge(var.common_tags, { Name = "${var.common_tags["Enviroment"]} Security Group For EC2-Web" })
}

#-----------------------------------------------------------------------

resource "aws_security_group" "web-ubuntu-alb" {
  name        = "WebServer-from-Terraform-SG-ALB"
  description = "Allow for ALB inbound traffic"
  vpc_id      = aws_vpc.vpc_for_web.id

  dynamic "ingress" {
    for_each = var.inbound_ports_ALB
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = merge(var.common_tags, { Name = "${var.common_tags["Enviroment"]} Security Group For ALB-Web" })
}

#----------------------------------------------------------------------#
#                             ALB                                      #
#----------------------------------------------------------------------#

resource "aws_launch_configuration" "web-ubuntu" {
  name_prefix     = "WebServer-from-Terraform-deploy-LC-"
  image_id        = data.aws_ami.latest-ubuntu-ami.id
  instance_type   = var.type_instance
  security_groups = [aws_security_group.web-ubuntu-ec2.id]
  key_name        = "EC2-Web"
  user_data       = file("user_data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

#-----------------------------------------------------------------------

resource "aws_autoscaling_group" "web-ubuntu" {
  name                 = "ASG-${aws_launch_configuration.web-ubuntu.name}"
  launch_configuration = aws_launch_configuration.web-ubuntu.name
  min_size             = var.autoscaling_min
  max_size             = var.autoscaling_max
  min_elb_capacity     = var.autoscaling_min_elb_capacity
  vpc_zone_identifier  = [aws_subnet.web-sub-public[0].id, aws_subnet.web-sub-public[1].id]
  health_check_type    = "ELB"
  load_balancers       = [aws_elb.web-ubuntu.name]
  
  dynamic "tag" {
    for_each = var.common_tags
    content{ 
      key = tag.key
      value = tag.value
      propagate_at_launch = true
    }
  } 

  lifecycle {
    create_before_destroy = true
  }
}

#-----------------------------------------------------------------------

resource "aws_elb" "web-ubuntu" {
  name            = "WebServer-ELB"
  security_groups = [aws_security_group.web-ubuntu-alb.id]
  subnets         = [aws_subnet.web-sub-public[0].id, aws_subnet.web-sub-public[1].id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }
  tags = merge(var.common_tags, { Name = "${var.common_tags["Enviroment"]} ELB for Web" })
}