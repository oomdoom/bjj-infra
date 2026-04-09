variable "region" {
  default = "us-east-1"
}

variable "db_user" {}
variable "db_password" {}

variable "eks_cluster_role_arn" {}
variable "eks_node_role_arn" {}