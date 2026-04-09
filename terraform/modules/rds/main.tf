resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "this" {
  identifier = var.name
  engine     = "postgres"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  username = var.db_user
  password = var.db_password
  db_name  = var.db_name
  publicly_accessible = false
  skip_final_snapshot = true
  vpc_security_group_ids = [var.db_sg]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  tags = var.tags
}