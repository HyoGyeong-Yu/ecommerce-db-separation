resource "aws_db_instance" "payment" {
  identifier             = "${var.project_name}-payment-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "payment_db"
  username               = "admin"
  password               = random_password.payment_db.result
  db_subnet_group_name   = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group.payment_db.id] # 다른 SG
  publicly_accessible    = false
  skip_final_snapshot    = true
  tags = { Name = "payment-db", Tier = "payment" }
}
