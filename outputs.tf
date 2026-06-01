# ─────────────────────────────────────────
# outputs.tf — Useful values printed after apply
# ─────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Map of AZ → public subnet ID (where ALB lives)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Map of AZ → private subnet ID (where EC2 lives)"
  value       = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  description = "ALB DNS name — use this to test before DNS propagates"
  value       = module.alb.alb_dns_name
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = module.ec2.private_ip
}

output "app_url" {
  description = "Your application URL"
  value       = "https://${var.domain_name}"
}

output "acm_cert_arn" {
  description = "ARN of the ACM TLS certificate"
  value       = module.dns.acm_cert_arn
}

output "route53_name_servers" {
  description = "Name servers for the Route53 hosted zone — point GoDaddy to these"
  value       = module.dns.name_servers
}
