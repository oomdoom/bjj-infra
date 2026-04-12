variable "name" {}
variable "cidr" {}
variable "cluster_name" {}
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "azs" { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}
