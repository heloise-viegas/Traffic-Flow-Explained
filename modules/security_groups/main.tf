# ═══════════════════════════════════════════════════════════
#  modules/security_groups/main.tf
#
#  Two security groups:
#  1. ALB SG  — accepts HTTPS (443) and HTTP (80) from internet
#  2. EC2 SG  — accepts port 80 ONLY from the ALB SG
#               accepts port 22 from anywhere (SSH, key-pair protected)
#
#  This enforces: internet → ALB → EC2 (never internet → EC2 directly)
# ═══════════════════════════════════════════════════════════

# ── ALB Security Group ────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTPS and HTTP from the internet to the ALB"
  vpc_id      = var.vpc_id

  # Allow HTTPS traffic from anywhere
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP traffic — ALB will redirect this to HTTPS
  ingress {
    description = "HTTP from internet (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic (ALB needs to talk to EC2)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ── EC2 Security Group ────────────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow HTTP from ALB only, SSH from anywhere"
  vpc_id      = var.vpc_id

  # Only the ALB security group can send traffic to port 80 on EC2
  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH access (protected by your key pair)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # Tip: replace 0.0.0.0/0 with your own IP for tighter security
  }

  # EC2 needs outbound internet access to pull Docker images
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}
