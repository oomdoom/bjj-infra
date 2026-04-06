# bjj-fast
basic fast api application for listing BJJ techniques

# BJJ API on AWS EKS

## Overview
This project provisions a production-style Kubernetes environment using Terraform.

## Architecture
- VPC with public/private subnets
- EKS cluster
- RDS PostgreSQL (private)
- ALB Ingress

## Security
- Secrets stored in AWS Secrets Manager
- IRSA used for pod-level access
- RDS not publicly accessible

## Observability
- /health endpoint
- /metrics endpoint
- Logs via CloudWatch

## Tradeoffs
- Single NAT Gateway used to reduce cost