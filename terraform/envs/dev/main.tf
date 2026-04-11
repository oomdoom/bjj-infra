provider "aws" {
  region = var.region
}

# -------------------
# IAM (Phase 1) — EKS roles only, no OIDC dependency
# Must exist before EKS so the cluster and node roles are ready.
# -------------------
module "iam" {
  source = "../../modules/iam"

  db_user     = var.db_user
  db_password = var.db_password
}

# -------------------
# VPC
# -------------------
module "vpc" {
  source = "../../modules/vpc"

  name            = "bjj-vpc"
  cidr            = "10.42.0.0/16"
  public_subnets  = ["10.42.1.0/24", "10.42.2.0/24"]
  private_subnets = ["10.42.101.0/24", "10.42.102.0/24"]
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
  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.eks_node_role_arn

  subnet_ids = module.vpc.private_subnet_ids
  cluster_sg = module.vpc.vpc_id

  desired_size   = 1
  max_size       = 2
  min_size       = 1
  instance_types = ["t3.medium"]

  depends_on = [module.iam]
}

# -------------------
# IRSA (Phase 2) — created after EKS so we have the OIDC provider ARN
# Gives the app pod permission to read from Secrets Manager.
# -------------------
resource "aws_iam_role" "irsa" {
  name = "bjj-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:bjj-app:bjj-api-sa"
        }
      }
    }]
  })

  depends_on = [module.eks]
}

resource "aws_iam_role_policy_attachment" "irsa_secrets" {
  role       = aws_iam_role.irsa.name
  policy_arn = module.iam.secrets_policy_arn
}

# -------------------
# RDS Security Group
# -------------------
resource "aws_security_group" "rds" {
  name        = "bjj-rds-sg"
  description = "Allow Postgres access from EKS cluster only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Postgres from EKS cluster"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.cluster_security_group_id]
  }

  egress {
    description = "Allow outbound only within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.42.0.0/16"]
  }

  tags = {
    Project = "bjj-api"
  }
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

  tags = {
    Project = "bjj-api"
  }
}