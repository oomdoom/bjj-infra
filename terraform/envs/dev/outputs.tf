output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "lb_controller_role_arn" {
  value = aws_iam_role.lb_controller.arn
}

output "secrets_policy_arn" {
  value = aws_iam_policy.secrets_access.arn
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}