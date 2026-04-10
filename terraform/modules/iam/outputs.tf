output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "irsa_role_arn" {
  value = aws_iam_role.irsa_role.arn
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}
