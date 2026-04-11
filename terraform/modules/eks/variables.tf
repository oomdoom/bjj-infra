variable "cluster_name" {}
variable "cluster_role_arn" {}
variable "node_role_arn" {}
variable "subnet_ids" {
  type = list(string)
}
variable "cluster_sg" {}
variable "desired_size" { default = 1 }
variable "max_size" { default = 2 }
variable "min_size" { default = 1 }
variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "tags" {
  type = map(string)
  default = {}
}