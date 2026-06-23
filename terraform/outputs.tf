output "member_db_endpoint" {
  description = "회원 DB 접속 엔드포인트"
  value       = aws_db_instance.member.address
}

output "payment_db_endpoint" {
  description = "결제 DB 접속 엔드포인트"
  value       = aws_db_instance.payment.address
}

output "dynamodb_table_name" {
  description = "장바구니 DynamoDB 테이블명"
  value       = aws_dynamodb_table.cart.name
}

output "app_ec2_id" {
  description = "앱 서버 인스턴스 ID (SSM 접속용)"
  value       = aws_instance.app.id
}

output "app_ec2_public_ip" {
  value = aws_instance.app.public_ip
}
