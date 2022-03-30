output "Available_Zone" {
  description = "available zones in region"
  value       = data.aws_availability_zones.zones.names
}

output "VPC_ID" {
  description = "vpc id"
  value       = data.aws_vpc.vpc_default.id
}

output "subnet_cidr_blocks" {
  description = "delault subnets"
  value       = [for sub in data.aws_subnet.sub_default : sub.cidr_block]
}

output "Default_SG" {
  description = "delault SG"
  value       = data.aws_security_groups.SG_default.ids
}
