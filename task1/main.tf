terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8.0"
    }
  }
  required_version = ">= 1.1.7"
}

provider "aws" {
  region     = "eu-central-1"
}

data "aws_availability_zones" "zones" {}

data "aws_vpc" "vpc_default" {
  default = true
}

data "aws_subnets" "subnets_default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_default.id]
  }
}

data "aws_subnet" "sub_default" {
  for_each = toset(data.aws_subnets.subnets_default.ids)
  id       = each.value
}

data "aws_security_groups" "SG_default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc_default.id]
  }
}