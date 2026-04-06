module "rds" {
  source = "../../modules/rds"

  db_user     = var.db_user
  db_password = var.db_password

  db_sg            = var.db_sg
  db_subnet_group  = var.db_subnet_group
}

module "iam" {
  source = "../../modules/iam"

  db_user     = var.db_user
  db_password = var.db_password
}