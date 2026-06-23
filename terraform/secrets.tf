# 랜덤 비밀번호 생성 (RDS 호환 위해 특수문자 제외)
resource "random_password" "member_db" {
  length  = 16
  special = false
}

resource "random_password" "payment_db" {
  length  = 16
  special = false
}

# ── 회원 DB 접속정보 ──
resource "aws_secretsmanager_secret" "member_db" {
  name                    = "${var.project_name}/member-db"
  recovery_window_in_days = 0 # destroy 후 즉시 삭제(재apply 시 이름 충돌 방지). 실무에선 7~30
}

resource "aws_secretsmanager_secret_version" "member_db" {
  secret_id = aws_secretsmanager_secret.member_db.id
  secret_string = jsonencode({
    host     = aws_db_instance.member.address
    username = aws_db_instance.member.username
    password = random_password.member_db.result
    dbname   = aws_db_instance.member.db_name
  })
}

# ── 결제 DB 접속정보 (별도 secret) ──
resource "aws_secretsmanager_secret" "payment_db" {
  name                    = "${var.project_name}/payment-db"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "payment_db" {
  secret_id = aws_secretsmanager_secret.payment_db.id
  secret_string = jsonencode({
    host     = aws_db_instance.payment.address
    username = aws_db_instance.payment.username
    password = random_password.payment_db.result
    dbname   = aws_db_instance.payment.db_name
  })
}
