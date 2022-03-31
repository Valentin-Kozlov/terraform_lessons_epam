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
  access_key = var.access_key
  secret_key = var.secret_key
}

#----------------------------------------------------------------------#
#                               AMI                                    #
#----------------------------------------------------------------------#

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

resource "aws_subnet" "web-sub-with-public" {
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
  tags = merge(var.common_tags,
  { Name = "${var.common_tags["Enviroment"]} Internet Gateway For Web" })
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
  tags = merge(var.common_tags,
  { Name = "${var.common_tags["Enviroment"]} Security Group For EC2-Web" })
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
  tags = merge(var.common_tags,
  { Name = "${var.common_tags["Enviroment"]} Security Group For ALB-Web" })
}

resource "aws_security_group" "web-ubuntu-rds" {
  name        = "WebServer-from-Terraform-deploy-SG-RDS"
  description = "Allow for RDS inbound traffic"
  vpc_id      = aws_vpc.vpc_for_web.id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
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
  tags = merge(var.common_tags,
  { Name = "${var.common_tags["Enviroment"]} Security Group For RDS-Web" })
}

#----------------------------------------------------------------------#
#                               ALB                                    #
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
  vpc_zone_identifier  = [for subnet in aws_subnet.web-sub-with-public : subnet.id]
  health_check_type    = "ELB"
  target_group_arns    = [aws_lb_target_group.tg-web.arn]

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

#-----------------------------------------------------------------------

resource "aws_lb" "web-alb" {
  name               = "WebServer-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-ubuntu-alb.id]
  subnets            = [for subnet in aws_subnet.web-sub-with-public : subnet.id]

  tags = merge(var.common_tags,
  { Name = "${var.common_tags["Enviroment"]} ALB for Web" })
}

resource "aws_lb_target_group" "tg-web" {
  name     = "WebServer-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_for_web.id
}

resource "aws_lb_listener" "web-listener" {
  load_balancer_arn = aws_lb.web-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-web.arn
  }
}

#----------------------------------------------------------------------#
#                               RDS                                    #
#----------------------------------------------------------------------#

resource "aws_db_instance" "db-for-web" {
  identifier_prefix = "db-for-web-"
  allocated_storage      = 10
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  port                   = var.db_port
  vpc_security_group_ids = [aws_security_group.web-ubuntu-rds.id]
  db_subnet_group_name   = aws_db_subnet_group.db-subnet.name
  publicly_accessible    = false
}

resource "aws_db_subnet_group" "db-subnet" {
  name_prefix = "${var.common_tags["Enviroment"]}-db-sub-for-web"
  subnet_ids  = [for subnet in aws_subnet.web-sub-with-public : subnet.id]

  tags = merge(var.common_tags,
  { Name = "${var.common_tags["Enviroment"]} DB subnet" })
}