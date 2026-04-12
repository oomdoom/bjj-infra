variable "region" {
  default = "us-east-1"
}

variable "db_user" {}
variable "db_password" {}
variable "oidc_provider_arn" { default = "" }
variable "oidc_provider" { default = "" }