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
output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "SNS Topic ARN for CloudWatch Alarms"
}

output "cloudwatch_alarms" {
  value = {
    member_db_cpu              = aws_cloudwatch_metric_alarm.member_db_cpu_high.alarm_name
    member_db_connections      = aws_cloudwatch_metric_alarm.member_db_connections.alarm_name
    payment_db_cpu             = aws_cloudwatch_metric_alarm.payment_db_cpu_high.alarm_name
    payment_db_connections     = aws_cloudwatch_metric_alarm.payment_db_connections.alarm_name
    dynamodb_user_errors       = aws_cloudwatch_metric_alarm.dynamodb_user_errors.alarm_name
    dynamodb_write_capacity    = aws_cloudwatch_metric_alarm.dynamodb_consumed_write_capacity.alarm_name
    ec2_cpu                    = aws_cloudwatch_metric_alarm.ec2_cpu_high.alarm_name
    ec2_status_check           = aws_cloudwatch_metric_alarm.ec2_status_check_failed.alarm_name
  }
  description = "CloudWatch Alarm names for monitoring"
}