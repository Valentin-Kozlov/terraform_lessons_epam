output "Public_DNS_WEB" {
  description = "public dns from elb"
  value       = aws_elb.web-ubuntu.dns_name
}