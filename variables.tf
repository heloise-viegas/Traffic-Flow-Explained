# ─────────────────────────────────────────
# Root variables — set values in terraform.tfvars
# ─────────────────────────────────────────

variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Short name used as a prefix on every resource (e.g. 'seqas')"
  type        = string
  default     = "seqas"
}

variable "domain_name" {
  description = "Your registered domain name (e.g. seqas.online)"
  type        = string
  default     = "seqas.online"
}

# ─── Networking ───────────────────────────
variable "vpc_cidr" {
  description = "IP range for the VPC (all subnets must fit inside this)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnets — key = AZ, value = CIDR. ALB requires at least 2 AZs."
  type        = map(string)
  default     = {
    "us-east-2a" = "10.0.1.0/24"
    "us-east-2b" = "10.0.2.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnets — key = AZ, value = CIDR. EC2 lives here."
  type        = map(string)
  default     = {
    "us-east-2a" = "10.0.10.0/24"
  }
}

# ─── EC2 ──────────────────────────────────
variable "ec2_instance_type" {
  description = "EC2 instance size (t3.micro is free-tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair for SSH access"
  type        = string
  # No default — you MUST set this in terraform.tfvars
}
