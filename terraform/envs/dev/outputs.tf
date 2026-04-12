output "eks_cluster_role_arn" {
  value = module.iam.eks_cluster_role_arn
}

output "eks_node_role_arn" {
  value = module.iam.eks_node_role_arn
}

output "lb_controller_role_arn" {
  value = module.iam.lb_controller_role_arn
}

output "secrets_policy_arn" {
  value = module.iam.secrets_policy_arn
}

output "db_secret_arn" {
  value = module.iam.db_secret_arn
}