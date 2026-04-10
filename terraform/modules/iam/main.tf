# -----------------------------
# 1. EKS Cluster Role
# -----------------------------
resource "aws_iam_role" "eks_cluster" {
  name = "bjj-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = "bjj-api"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------
# 2. EKS Node Role
# -----------------------------
resource "aws_iam_role" "eks_node" {
  name = "bjj-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project = "bjj-api"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -----------------------------
# 3. Secrets Manager
# -----------------------------
resource "aws_secretsmanager_secret" "db" {
  name = "bjj-db-secret"

  tags = {
    Project = "bjj-api"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_user
    password = var.db_password
  })
}

# -----------------------------
# 4. IAM Policy (Secrets Access)
# -----------------------------
resource "aws_iam_policy" "secrets_access" {
  name = "bjj-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.db.arn
    }]
  })
}

# -----------------------------
# 5. IRSA Role (pod-level secrets access)
# -----------------------------
resource "aws_iam_role" "irsa_role" {
  name = "bjj-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" = "system:serviceaccount:${var.eks_namespace}:${var.eks_service_account_name}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "irsa_secrets_attach" {
  role       = aws_iam_role.irsa_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}
