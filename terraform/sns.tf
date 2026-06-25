# SNS Topic — CloudWatch 알람 알림 받기
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Purpose     = "CloudWatch Alarms"
    Environment = "production"
  }
}

# SNS Subscription — 이메일로 알람 받기
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}