# ═══════════════════════════════════════════════════════════
#  modules/ec2/main.tf
#
#  EC2 instance in the private subnet running nginx in Docker.
#
#  On first boot, user_data:
#    1. Updates packages
#    2. Installs Docker
#    3. Pulls and runs the official nginx container on port 80
#
#  The instance registers itself with the ALB Target Group.
# ═══════════════════════════════════════════════════════════

# ── Look up the latest Ubuntu 22.04 AMI ───────────────────
# This data source finds the correct AMI ID automatically for
# your region, so you never have to hard-code it.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]   # Canonical (official Ubuntu publisher)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── EC2 Instance ──────────────────────────────────────────
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [var.ec2_sg_id]
  key_name               = var.key_pair_name

  # user_data runs once on first boot as root
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system packages
    apt-get update -y

    # Install Docker
    apt-get install -y docker.io

    # Start Docker and enable it to run on reboot
    systemctl start docker
    systemctl enable docker

    # Pull and run the official nginx image
    # -d  = run in background (detached)
    # -p  = map container port 80 to host port 80
    # --name nginx = friendly name for the container
    # --restart always = auto-restart if the instance reboots
    docker run -d \
      -p 80:80 \
      --name nginx \
      --restart always \
      nginx
  EOF

  tags = {
    Name = "${var.project_name}-app-server"
  }
}

# ── Register EC2 with the ALB Target Group ────────────────
# This is what tells the ALB to send traffic to this instance.
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.app.id
  port             = 80
}
