output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name (e.g. seqas-alb-123456.us-east-2.elb.amazonaws.com)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID — needed for the Route53 alias record"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "Target Group ARN — EC2 instance registers to this"
  value       = aws_lb_target_group.main.arn
}
