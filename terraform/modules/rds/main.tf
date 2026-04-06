resource "aws_db_instance" "postgres" {
  identifier = "bjj-db"

  engine         = "postgres"
  instance_class = "db.t3.micro"
  allocated_storage = 20

  db_name  = "bjj"

  username = var.db_user
  password = var.db_password

  publicly_accessible = false
  skip_final_snapshot = true

  vpc_security_group_ids = [var.db_sg]
  db_subnet_group_name   = var.db_subnet_group
}