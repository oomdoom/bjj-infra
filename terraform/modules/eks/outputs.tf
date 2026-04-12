output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

# The cluster-managed node security group — used to scope RDS ingress
# so only EKS nodes can reach Postgres, not the open internet.
output "node_security_group_id" {
  value = aws_eks_node_group.this.resources[0].remote_access_security_group_id != null ? (
    aws_eks_node_group.this.resources[0].remote_access_security_group_id
  ) : aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider" {
  value = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}
