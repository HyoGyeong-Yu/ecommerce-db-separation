resource "aws_db_instance" "member" {
  identifier             = "${var.project_name}-member-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # Free Tier
  allocated_storage      = 20
  db_name                = "member_db"
  username               = "admin"
  password               = random_password.member_db.result
  db_subnet_group_name   = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group.member_db.id]
  publicly_accessible    = false
  multi_az               = var.member_db_multi_az
  apply_immediately      = true
  skip_final_snapshot    = true
  tags = { Name = "member-db", Tier = "member" }
}
