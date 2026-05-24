# Cloud Traffic Flow Explained — End-to-End AWS & Azure Architecture

## Introduction

When a user types a URL like:

```text
https://seqas.online
```

a large number of networking, security, DNS, routing, and infrastructure components work together behind the scenes before the request finally reaches the application.

This project explains the complete end-to-end request flow in modern cloud-native architectures using:

* AWS
* Azure
* DNS
* CDN
* WAF
* Load Balancers
* API Gateways
* Private Networking
* Containers
* Kubernetes concepts

The goal of this project is not just to explain theory, but to explain how real production-grade architectures are designed and how internet traffic actually flows through cloud infrastructure.

---

# AWS Traffic Flow Architecture

## High-Level AWS Architecture

```text
User Browser
       ↓
DNS Resolver
       ↓
.online TLD Nameservers
       ↓
Route53 Hosted Zone
       ↓
Application Load Balancer (Public Subnet)
       ↓
Target Group
       ↓
EC2 Instance (Private Subnet)
       ↓
Docker Container (nginx)
```

---

# AWS End-to-End Request Flow

* When a user enters `https://seqas.online` in the browser, the browser first performs DNS resolution to identify where the application is hosted.

* The request goes to a recursive DNS resolver such as:

  * Google DNS
  * Cloudflare DNS
  * ISP DNS server

* The resolver queries the `.online` TLD nameservers to identify the authoritative nameservers for the domain.

* Since the domain nameservers were delegated from GoDaddy to Amazon Route53, the resolver is directed to the Route53 nameservers.

* Amazon Route53 then returns the DNS record pointing to the Application Load Balancer (ALB).

* Once the browser receives the ALB endpoint, it sends the HTTPS request to the ALB over the internet.

* The request enters the AWS VPC through the Internet Gateway (IGW).

* The ALB is deployed inside public subnets, which contain route table entries pointing to the Internet Gateway, allowing internet traffic to reach the load balancer.

* The ALB receives the HTTPS request on port 443 and terminates the TLS/SSL connection using the ACM certificate.

* The ALB listener evaluates routing rules and forwards the request to the configured Target Group.

* The Target Group identifies a healthy EC2 instance running inside a private subnet.

* Unlike public subnets, private subnets do not have direct internet access through the Internet Gateway.

* The request flows internally from the public subnet (ALB layer) to the private subnet (application layer) using AWS internal VPC networking.

* Security Groups control this communication by allowing traffic only from the ALB Security Group to the EC2 Security Group on port 80.

* The EC2 instance receives the request and forwards it to the Docker container where nginx is running.

* nginx processes the request and generates the response.

* The response then travels back through the same path:

```text
nginx → EC2 → Target Group → ALB → Internet Gateway → User Browser
```

---

# Understanding Public vs Private Subnet Traffic Flow

## Public Subnets

Public subnets contain resources that must be reachable from the internet.

Examples:

* Application Load Balancers
* Bastion Hosts
* NAT Gateways

Public subnets contain route table entries such as:

```text
0.0.0.0/0 → Internet Gateway
```

This allows internet traffic to enter and leave the subnet.

---

## Private Subnets

Private subnets contain backend application infrastructure that should not be directly exposed to the internet.

Examples:

* EC2 application servers
* Kubernetes worker nodes
* Databases
* Internal services

Private subnets do NOT contain direct routes to the Internet Gateway.

Instead:

* outbound internet access is usually provided through NAT Gateway
* inbound traffic comes internally through the ALB

This creates a layered security model.

---

# Why ALB Is Deployed in Public Subnets

The Application Load Balancer acts as the public entry point for internet traffic.

Because users on the internet must reach it directly, the ALB:

* requires public IP accessibility
* must be connected to the Internet Gateway
* therefore must reside in public subnets

---

# Why EC2 Is Deployed in Private Subnets

The EC2 instance hosting the application is intentionally deployed inside private subnets.

This improves security because:

* the EC2 instance is not directly exposed to the internet
* all ingress traffic must pass through the ALB
* security policies can be centralized
* attack surface is reduced significantly

This is one of the most common production-grade cloud architecture patterns.

---

# DNS Resolution Explained

## Domain Registrar

The domain was purchased using GoDaddy.

The registrar controls:

* ownership of the domain
* nameserver delegation

---

## Route53 Hosted Zone

Amazon Route53 hosts the DNS records for the domain.

The hosted zone stores records such as:

* A Records
* Alias Records
* CNAME Records
* NS Records

---

## Nameserver Delegation

The nameservers configured in GoDaddy were updated to point to Route53 nameservers.

This delegated authoritative DNS control from GoDaddy to AWS.

Example:

```text
GoDaddy
   ↓
Route53 Nameservers
   ↓
AWS DNS Resolution
```

---

# TLS/SSL Flow Using ACM

The HTTPS certificate was generated using AWS Certificate Manager (ACM).

Flow:

```text
Browser
   ↓ HTTPS
ALB
   ↓ HTTP
EC2/nginx
```

The TLS connection terminates at the ALB.

This means:

* the ALB handles encryption
* EC2 instances do not require certificates
* backend infrastructure remains simpler

This is extremely common in production systems.

---

# Target Groups Explained

The Application Load Balancer does not directly communicate with Docker containers.

Instead:

```text
ALB
   ↓
Target Group
   ↓
EC2 Instance
```

The Target Group:

* maintains healthy backend targets
* performs health checks
* forwards traffic only to healthy instances

---

# Health Check Flow

The ALB continuously checks backend health.

Health Check Flow:

```text
ALB
   ↓
GET /
   ↓
EC2:80
   ↓
nginx returns HTTP 200
```

If the backend fails:

* target becomes unhealthy
* traffic stops routing to that target automatically

This provides resiliency and fault isolation.

---

# Security Group Architecture

## ALB Security Group

Allows:

* HTTP 80 from internet
* HTTPS 443 from internet

---

## EC2 Security Group

Allows:

* HTTP 80 only from ALB Security Group

This ensures:

* EC2 is never publicly exposed
* only the ALB can communicate with the backend

---

# Docker Layer

Docker was used to run nginx inside the EC2 instance.

Container launch command:

```bash
sudo docker run -d \
--restart unless-stopped \
--name nginx \
-p 80:80 nginx
```

This maps:

```text
EC2 Port 80 → Container Port 80
```

---

# NAT Gateway and Private Internet Access

The EC2 instance resides inside a private subnet.

Private subnets do not have direct internet access.

To allow outbound traffic such as:

* package downloads
* Docker image pulls
* OS updates

traffic is routed through the NAT Gateway.

Flow:

```text
Private EC2
   ↓
Private Route Table
   ↓
NAT Gateway
   ↓
Internet Gateway
   ↓
Internet
```

---

# Real Issues Encountered During Setup

## 1. DNS Propagation Delay

After updating nameservers in GoDaddy, ACM validation initially failed because DNS propagation had not completed globally.

---

## 2. ACM Certificate Stayed Pending

The ACM certificate remained in `Pending Validation` until Route53 became publicly authoritative.

---

## 3. HTTPS Listener Could Not Detect Certificate

The ALB HTTPS listener could not display the ACM certificate until certificate status became:

```text
Issued
```

---

## 4. Difference Between Hosted Zone and Domain Ownership

Creating a Route53 hosted zone does NOT mean the domain is owned.

Domain ownership is controlled by:

* GoDaddy
* Namecheap
* Cloudflare Registrar
* other registrars

Route53 only hosts DNS records.

---

## 5. Docker Container Was Not Running

After stopping the EC2 instance, the nginx container stopped running.

This caused:

* Target Group unhealthy state
* ALB failures
* application downtime

This demonstrated an important operational concept:

```text
Infrastructure can be healthy while application runtime is unhealthy.
```

---

## 6. Layered Debugging Was Critical

The infrastructure had to be debugged layer-by-layer:

```text
DNS
↓
TLS
↓
ALB
↓
Target Group
↓
EC2
↓
Docker Runtime
```

This mirrors real-world cloud troubleshooting.

---

# Cost Optimization Learnings

One of the biggest learnings from this setup was that networking infrastructure can cost more than compute resources.

---

## Biggest Cost Contributors

* NAT Gateway
* Application Load Balancer
* Cross-AZ networking

---

## Important Observation

Even when EC2 instances are stopped:

* NAT Gateway still incurs charges
* ALB still incurs charges
* Route53 hosted zones still incur charges

---

## Production vs Learning Tradeoff

### Production Design

* Multi-AZ NAT Gateways
* High availability
* Higher resiliency
* Higher cost

### Learning/Lab Design

* Single NAT Gateway
* Lower cost
* Reduced redundancy

Architects constantly balance:

```text
Reliability ↔ Cost ↔ Complexity
```

---

# Future Improvements

This architecture can be extended further using:

* Amazon CloudFront
* AWS WAF
* AWS Shield
* API Gateway
* VPC Link
* Auto Scaling Groups
* ECS/EKS
* Terraform
* CI/CD pipelines
* Observability and monitoring stacks

---

# Azure Traffic Flow Architecture

## Azure End-to-End Request Flow

* User enters a request in the browser:

```text
www.example.com
```

* The request first reaches the DNS layer, such as Azure DNS.

* Azure DNS resolves the domain name into the IP address of the application entry point and directs the traffic into Azure infrastructure.

* The request then passes through Azure WAF (Web Application Firewall).

* Azure WAF inspects incoming traffic for malicious requests such as:

  * SQL Injection attacks
  * XSS attacks
  * Bot traffic
  * IP abuse
  * Rate-limit violations

* Any malicious or suspicious requests are blocked immediately before reaching the application infrastructure.

* After passing security checks, the request reaches the CDN and edge routing layer, typically Azure Front Door or Azure CDN.

* Azure Front Door serves static content such as:

  * Images
  * CSS files
  * JavaScript files
  * Cached frontend assets

* These static assets are delivered from edge locations closest to the user, which:

  * Reduces latency
  * Improves performance
  * Reduces backend load

* If the request contains dynamic or non-cacheable content, Azure Front Door forwards that request toward the backend infrastructure inside the Azure Virtual Network (VNet).

* The request enters the Azure VNet through the public networking layer and internet-facing endpoints.

* Inside the VNet, the traffic is routed toward the Azure Application Gateway or Azure Load Balancer.

* Typically, Azure DNS resolves the domain to the public endpoint of the Application Gateway.

* The Application Gateway is responsible for:

  * Distributing traffic
  * Performing health checks
  * SSL termination
  * URL/path-based routing
  * Sending requests only to healthy backend targets

* The backend targets may include:

  * Kubernetes pods running inside Azure Kubernetes Service (AKS)
  * Virtual Machines (VMs)
  * Application nodes hosted in private subnets

* The Application Gateway forwards traffic to targets registered in its backend pool.

* In many enterprise architectures, Azure API Management (APIM) may exist before or after the Application Gateway depending on the design.

* Azure API Management provides capabilities such as:

  * Authentication
  * Authorization
  * Rate limiting
  * API throttling
  * Request transformation
  * JWT validation
  * API versioning

* After passing through all these layers, the request finally reaches:

  * Kubernetes pods
  * Backend application servers
  * Microservices running inside AKS or Virtual Machines

* The backend application processes the request and sends the response back to the user through the same path in reverse order.

---

# Final Thoughts

Modern cloud architectures are layered systems where DNS, security, networking, routing, TLS, containers, and compute all work together.

Understanding how traffic flows through these layers is one of the most important skills for cloud engineers, DevOps engineers, and solutions architects.

This project demonstrates not only the theoretical request flow, but also the operational realities encountered while implementing real infrastructure in AWS.
