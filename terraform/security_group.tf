# ── 이 프로젝트의 핵심: SG 3개로 네트워크 경계 구현 ──

# 앱 서버 SG
resource "aws_security_group" "app" {
  name   = "${var.project_name}-app-sg"
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-app-sg" }
}

# 앱 SG 아웃바운드 — RDS / DynamoDB / Secrets Manager / 인터넷 접근용
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# 회원 DB SG — 앱 서버에서만 3306 허용
resource "aws_security_group" "member_db" {
  name   = "${var.project_name}-member-db-sg"
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-member-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "member_db_from_app" {
  security_group_id            = aws_security_group.member_db.id
  referenced_security_group_id = aws_security_group.app.id # 앱 SG만 허용
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

# 결제 DB SG — 앱 서버에서만, 회원 DB SG와는 별도
resource "aws_security_group" "payment_db" {
  name   = "${var.project_name}-payment-db-sg"
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-payment-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "payment_db_from_app" {
  security_group_id            = aws_security_group.payment_db.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  # 포인트: member_db SG에서 payment_db로는 접근 불가
}
