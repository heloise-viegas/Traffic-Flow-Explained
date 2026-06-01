output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.app.private_ip
}

output "ami_id" {
  description = "AMI ID used (Ubuntu 22.04)"
  value       = data.aws_ami.ubuntu.id
}
