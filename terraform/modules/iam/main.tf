# -----------------------------
# 1. Secrets Manager
# -----------------------------
resource "aws_secretsmanager_secret" "db" {
  name = "bjj-db-secret"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_user
    password = var.db_password
  })
}

# -----------------------------
# 2. IAM Policy
# -----------------------------
resource "aws_iam_policy" "secrets_access" {
  name = "bjj-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["secretsmanager:GetSecretValue"],
      Resource = aws_secretsmanager_secret.db.arn
    }]
  })
}

# -----------------------------
# 3. IAM Role for IRSA
# -----------------------------
resource "aws_iam_role" "irsa_role" {
  name = "bjj-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = var.oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${var.oidc_provider}:sub" = "system:serviceaccount:${var.eks_namespace}:${var.eks_service_account_name}"
        }
      }
    }]
  })
}

# -----------------------------
# 4. Attach policy to role
# -----------------------------
resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.irsa_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}