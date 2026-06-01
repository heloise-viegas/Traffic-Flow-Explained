# ═══════════════════════════════════════════════════════════
#  main.tf — Root module
#  Wires together all child modules in dependency order:
#  vpc → security_groups → dns → alb → ec2
#  Then adds the Route 53 alias record that points to the ALB.
# ═══════════════════════════════════════════════════════════

# ── 1. VPC, Subnets, IGW, NAT, Route Tables ──────────────
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  aws_region           = var.aws_region
}

# ── 2. Security Groups ────────────────────────────────────
module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

# ── 3. DNS — Route53 Hosted Zone + ACM Certificate ───────
#  We create the cert BEFORE the ALB so we can attach it to
#  the HTTPS listener.
module "dns" {
  source = "./modules/dns"

  project_name = var.project_name
  domain_name  = var.domain_name
}

# ── 4. ALB — Load Balancer + Target Group + Listeners ────
module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = values(module.vpc.public_subnet_ids)   # convert map → list for ALB
  alb_sg_id         = module.security_groups.alb_sg_id
  acm_cert_arn      = module.dns.acm_cert_arn
}

# ── 5. EC2 — Instance in Private Subnet running nginx ────
module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  private_subnet_id = values(module.vpc.private_subnet_ids)[0]   # first private subnet
  ec2_sg_id         = module.security_groups.ec2_sg_id
  instance_type     = var.ec2_instance_type
  key_pair_name     = var.key_pair_name
  target_group_arn  = module.alb.target_group_arn
}

# ── 6. Route53 Alias Record → ALB ────────────────────────
#  This is done here (not inside the dns module) because
#  it needs outputs from BOTH the dns module and the alb module.
resource "aws_route53_record" "app" {
  zone_id = module.dns.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
