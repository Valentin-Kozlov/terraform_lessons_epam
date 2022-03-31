variable "access_key" {
  type        = string
  description = "Please enter your access key"
  sensitive   = true
}

variable "secret_key" {
  type        = string
  description = "Please enter your secret key"
  sensitive   = true
}

variable "region_name" {
  type        = string
  description = "Please enter your region name for deploy"
  default     = "eu-central-1"
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "vpc_cidr" {
  type        = string
  description = "Please enter CIDR for your VPC"
  default     = "192.168.0.0/16"
}

variable "subnets-public" {
  type    = list(string)
  default = ["192.168.101.0/24", "192.168.202.0/24"]
}

variable "inbound_ports_EC2" {
  type        = list(any)
  description = "Please enter access ports for inbound traffic in EC2 instance"
  default     = ["80", "443", "22"]
}

variable "inbound_ports_ALB" {
  type        = list(any)
  description = "Please enter access ports for inbound traffic in ALB"
  default     = ["80", "443"]
}

variable "type_instance" {
  type        = string
  description = "Please enter type instance"
  default     = "t2.micro"
}

variable "common_tags" {
  type        = map(any)
  description = "Please enter your common tags for services"
  default = {
    Owners     = "Valentin Kozlov"
    Builder    = "by Terraform"
    Enviroment = "dev"
  }
}

variable "autoscaling_min" {
  type        = string
  description = "Please enter minimum instances"
  default     = "2"
}

variable "autoscaling_max" {
  type        = string
  description = "Please enter maximum instances"
  default     = "2"
}

variable "autoscaling_min_elb_capacity" {
  type    = string
  default = "2"
}

variable "db_engine" {
  description = "Please enter engine for your DB"
  type        = string
  default     = "mariadb"
}

variable "db_engine_version" {
  description = "Please enter engine version for your DB"
  type        = string
  default     = "10.6.7"
}

variable "db_instance_class" {
  description = "Please enter instance type for your DB"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Please enter name your DB"
  type        = string
  default     = "dbweb"
}

variable "db_username" {
  description = "Please enter your username for DB"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Please enter your password for DB user"
  type        = string
  default     = "PaSsWoRd"
  sensitive   = true
}

variable "db_port" {
  description = "Please enter port for DB"
  type        = string
  default     = "3306"
}