output "Public_DNS_WEB" {
  description = "public dns from elb"
  value       = aws_lb.web-alb.dns_name
}

output "dns_name_db" {
  description = "dns db"
  value       = aws_db_instance.db-for-web.address
}
