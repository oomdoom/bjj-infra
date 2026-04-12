provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

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
# EKS Control Plane Security Group
# -------------------
resource "aws_security_group" "eks_cluster" {
  name        = "bjj-eks-cluster-sg"
  description = "EKS cluster control plane security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.42.0.0/16"]
  }

  egress {
    description = "HTTPS to internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP to internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.42.0.0/16"]
  }

  tags = {
    Project = "bjj-api"
    Name    = "bjj-eks-cluster-sg"
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
  cluster_sg = aws_security_group.eks_cluster.id

  desired_size   = 1
  max_size       = 2
  min_size       = 1
  instance_types = ["t3.medium"]

  depends_on = [module.iam]
}

# -------------------
# IRSA (Phase 2) — created after EKS so we have the OIDC provider ARN
# -------------------
resource "aws_iam_role" "irsa" {
  name = "bjj-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
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

resource "aws_iam_role_policy_attachment" "irsa_lb_controller" {
  role       = aws_iam_role.irsa.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# -------------------
# AWS Load Balancer Controller
# -------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.irsa.arn
  }

  depends_on = [module.eks, aws_iam_role.irsa]
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
