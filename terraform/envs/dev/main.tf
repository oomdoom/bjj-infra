provider "aws" {
  region = var.region
}

# -------------------
# VPC
# -------------------
module "vpc" {
  source = "../../modules/vpc"

  name            = "bjj-vpc"
  cidr            = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]
  azs             = ["us-east-1a", "us-east-1b"]

  tags = {
    Project = "bjj-api"
  }
}

# -------------------
# EKS
# -------------------
module "eks" {
  source = "../../modules/eks"

  cluster_name     = "bjj-eks"
  cluster_role_arn = var.eks_cluster_role_arn
  node_role_arn    = var.eks_node_role_arn

  subnet_ids = module.vpc.private_subnet_ids
  cluster_sg = module.vpc.vpc_id

  desired_size   = 1
  max_size       = 2
  min_size       = 1
  instance_types = ["t3.medium"]
}

# -------------------
# RDS
# -------------------
module "rds" {
  source = "../../modules/rds"

  name        = "bjj-db"
  db_user     = var.db_user
  db_password = var.db_password
  db_name     = "bjj"

  subnet_ids = module.vpc.private_subnet_ids
  db_sg      = aws_security_group.rds.id
}

resource "aws_security_group" "rds" {
  name   = "bjj-rds-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # TEMP: allow all (fix later)
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------
# IAM (IRSA + Secrets)
# -------------------
module "iam" {
  source = "../../modules/iam"

  db_user     = var.db_user
  db_password = var.db_password

  eks_namespace             = "default"
  eks_service_account_name  = "bjj-api-sa"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider     = module.eks.oidc_provider
}