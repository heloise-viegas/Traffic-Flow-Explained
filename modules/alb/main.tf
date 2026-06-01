# ═══════════════════════════════════════════════════════════
#  modules/alb/main.tf
#
#  Application Load Balancer setup:
#  1. ALB          — internet-facing, lives in public subnets
#  2. Target Group — health-checks EC2 instances on port 80
#  3. Listener 443 — terminates TLS, forwards to target group
#  4. Listener 80  — redirects HTTP → HTTPS (best practice)
# ═══════════════════════════════════════════════════════════

# ── Application Load Balancer ─────────────────────────────
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false              # internet-facing
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids   # must span at least 2 AZs

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# ── Target Group ──────────────────────────────────────────
# Defines where the ALB sends traffic (EC2 instances on port 80)
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health check — ALB will only route to EC2 if this passes
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30    # check every 30 seconds
    timeout             = 5
    healthy_threshold   = 2     # 2 passing checks = healthy
    unhealthy_threshold = 3     # 3 failing checks = unhealthy
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# ── HTTPS Listener (port 443) ─────────────────────────────
# Terminates TLS using the ACM certificate, then forwards to EC2
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"   # modern TLS policy
  certificate_arn   = var.acm_cert_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ── HTTP Listener (port 80) ───────────────────────────────
# Redirects all HTTP traffic to HTTPS automatically
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"   # permanent redirect
    }
  }
}
