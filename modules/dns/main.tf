# ═══════════════════════════════════════════════════════════
#  modules/dns/main.tf
#
#  Step 1 of DNS setup (runs BEFORE the ALB is created):
#    - Route53 Hosted Zone for your domain
#    - ACM TLS certificate (needed by the ALB HTTPS listener)
#    - DNS validation records (proves to AWS you own the domain)
#
#  Step 2 (the A record pointing to the ALB) lives in main.tf
#  at the root because it depends on both this module and the ALB module.
#
#  ⚠️  IMPORTANT after first apply:
#  Run `terraform output route53_name_servers` and update your
#  GoDaddy nameservers to point to these four values.
#  ACM certificate validation will hang until you do this.
# ═══════════════════════════════════════════════════════════

# ── Route53 Hosted Zone ───────────────────────────────────
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${var.project_name}-hosted-zone"
  }
}

# ── ACM Certificate ───────────────────────────────────────
# Request a certificate for the domain (and www. subdomain)
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"   # AWS adds a CNAME record to prove ownership

  # Best practice: create the new cert before destroying the old one
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-acm-cert"
  }
}

# ── DNS Validation Records ────────────────────────────────
# AWS needs to verify you own the domain before issuing the cert.
# This block automatically adds the required CNAME records to Route53.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for option in aws_acm_certificate.main.domain_validation_options :
    option.domain_name => option
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 60
  records = [each.value.resource_record_value]
}

# ── Wait for Certificate to be Issued ────────────────────
# Terraform will pause here until AWS confirms the cert is valid.
# This can take a few minutes after the CNAME records propagate.
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
