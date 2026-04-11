variable "name" {}
variable "db_user" {}
variable "db_password" {}
variable "db_name" { default = "bjj" }
variable "subnet_ids" { type = list(string) }
variable "db_sg" {}
variable "tags" { type = map(string) }