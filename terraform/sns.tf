# SNS Topic — CloudWatch 알람 알림 받기
# SNS 암호화 미적용: AWS 관리 키(aws/sns)로 암호화하면 CloudWatch 알람이 kms:GenerateDataKey 권한을 얻지 못해
# 알림이 조용히 유실됨. CMK($1/월)로 해결 가능하나 알람 파이프라인 안정성 + 비용 고려로 예외
#tfsec:ignore:aws-sns-enable-topic-encryption
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