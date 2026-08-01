# tfsec 예외 사유:
# - 스토리지 암호화: 기존 인스턴스는 재생성 없이 암호화 불가 → 스냅샷 복원 마이그레이션 필요 (실측 데이터 보존 위해 예외)
# - IAM DB 인증(AVD-AWS-0176): Secrets Manager 기반 자격증명 관리 채택 (설계 선택)
# - 삭제 보호(AVD-AWS-0177): 포트폴리오 환경, terraform destroy 용이성 우선
#tfsec:ignore:aws-rds-encrypt-instance-storage-data tfsec:ignore:AVD-AWS-0176 tfsec:ignore:AVD-AWS-0177
resource "aws_db_instance" "member" {
  identifier              = "${var.project_name}-member-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro" # Free Tier
  allocated_storage       = 20
  db_name                 = "member_db"
  username                = "admin"
  password                = random_password.member_db.result
  db_subnet_group_name    = aws_db_subnet_group.private.name
  vpc_security_group_ids  = [aws_security_group.member_db.id]
  publicly_accessible     = false
  multi_az                = var.member_db_multi_az
  apply_immediately       = true
  skip_final_snapshot     = true
  backup_retention_period = 7
  tags                    = { Name = "member-db", Tier = "member" }
}
