# ============================================================================
# CloudWatch Alarms for Fault Scenarios
# ============================================================================

# SCENARIO 1: 회원 DB 연결 실패
resource "aws_cloudwatch_metric_alarm" "member_db_cpu_high" {
  alarm_name          = "${var.project_name}-member-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when member DB CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.member.identifier
  }

  tags = { Name = "member-db-cpu-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "member_db_connections" {
  alarm_name          = "${var.project_name}-member-db-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "Alert when member DB connections exceed 50"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.member.identifier
  }

  tags = { Name = "member-db-connections-alarm" }
}

# SCENARIO 2: 결제 DB 연결 실패
resource "aws_cloudwatch_metric_alarm" "payment_db_cpu_high" {
  alarm_name          = "${var.project_name}-payment-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when payment DB CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.payment.identifier
  }

  tags = { Name = "payment-db-cpu-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "payment_db_connections" {
  alarm_name          = "${var.project_name}-payment-db-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "Alert when payment DB connections exceed 50"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.payment.identifier
  }

  tags = { Name = "payment-db-connections-alarm" }
}

# SCENARIO 3: DynamoDB 쓰기 실패
resource "aws_cloudwatch_metric_alarm" "dynamodb_user_errors" {
  alarm_name          = "${var.project_name}-dynamodb-user-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert when DynamoDB returns user errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.cart.name
  }

  tags = { Name = "dynamodb-user-errors-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_consumed_write_capacity" {
  alarm_name          = "${var.project_name}-dynamodb-write-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ConsumedWriteCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "500"
  alarm_description   = "Alert when DynamoDB write capacity is high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.cart.name
  }

  tags = { Name = "dynamodb-write-capacity-alarm" }
}

# SCENARIO 4: EC2 접근 불가
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${var.project_name}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when EC2 CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  tags = { Name = "ec2-cpu-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  alarm_name          = "${var.project_name}-ec2-status-check-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert when EC2 status check fails"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.app.id
  }

  tags = { Name = "ec2-status-check-alarm" }
}

# RDS 디스크 공간 부족
resource "aws_cloudwatch_metric_alarm" "member_db_storage_low" {
  alarm_name          = "${var.project_name}-member-db-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1073741824"
  alarm_description   = "Alert when member DB free storage is below 1GB"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.member.identifier
  }

  tags = { Name = "member-db-storage-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "payment_db_storage_low" {
  alarm_name          = "${var.project_name}-payment-db-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1073741824"
  alarm_description   = "Alert when payment DB free storage is below 1GB"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.payment.identifier
  }

  tags = { Name = "payment-db-storage-alarm" }
}