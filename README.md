# AWS Traffic Flow Architecture

- User enters a request in the browser:

  ```text
  www.example.com
  ```

- The request first reaches the DNS layer, such as Amazon Route 53.

- Route 53 resolves the domain name into the IP address of the application entry point and directs the traffic into AWS infrastructure.

- The request then passes through AWS WAF (Web Application Firewall).

- AWS WAF inspects incoming traffic for malicious requests such as:
  - SQL Injection attacks
  - XSS attacks
  - Bot traffic
  - IP abuse
  - Rate-limit violations

- Any malicious or suspicious requests are blocked immediately before reaching the application infrastructure.

- After passing security checks, the request reaches the CDN layer, typically Amazon CloudFront.

- CloudFront serves static content such as:
  - Images
  - CSS files
  - JavaScript files
  - Cached frontend assets

- These static assets are delivered from edge locations closest to the user, which:
  - Reduces latency
  - Improves performance
  - Reduces backend load

- If the request contains dynamic or non-cacheable content, CloudFront forwards that request toward the backend infrastructure inside the AWS VPC.

- The request enters the VPC through the Internet Gateway.

- The Internet Gateway acts as the bridge between:
  - The public internet
  - Resources hosted inside the VPC

- Inside the VPC, the traffic is routed toward the Elastic Load Balancer (ELB).

- Typically, Route 53 resolves the domain to the public endpoint of this load balancer.

- The Elastic Load Balancer is responsible for:
  - Distributing traffic
  - Performing health checks
  - Sending requests only to healthy backend targets

- The backend targets may include:
  - Kubernetes pods running inside Amazon EKS
  - EC2 instances
  - Application nodes hosted in private subnets

- The ELB forwards traffic to targets registered inside its target group.

- In many enterprise architectures, an API Gateway may exist before or after the ELB depending on the design.

- The API Gateway provides capabilities such as:
  - Authentication
  - Authorization
  - Rate limiting
  - API throttling
  - Request transformation
  - JWT validation
  - API versioning

- After passing through all these layers, the request finally reaches:
  - Kubernetes pods
  - Backend application servers
  - Microservices running inside EKS or EC2

- The backend application processes the request and sends the response back to the user through the same path in reverse order.
