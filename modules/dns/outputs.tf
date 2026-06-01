output "hosted_zone_id" {
  description = "Route53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Route53 name servers — update GoDaddy to point to these"
  value       = aws_route53_zone.main.name_servers
}

output "acm_cert_arn" {
  description = "ACM Certificate ARN (used by the ALB HTTPS listener)"
  value       = aws_acm_certificate_validation.main.certificate_arn
}
