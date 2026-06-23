# EC2가 사용할 IAM Role
resource "aws_iam_role" "app_ec2" {
  name = "${var.project_name}-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# 최소권한: 본인 secret 2개만 읽기 가능
resource "aws_iam_role_policy" "secrets_read" {
  name = "${var.project_name}-secrets-read"
  role = aws_iam_role.app_ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        aws_secretsmanager_secret.member_db.arn,
        aws_secretsmanager_secret.payment_db.arn
      ]
    }]
  })
}

# 키페어 없이 SSM Session Manager로 EC2 접속하기 위한 권한
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2에 Role을 붙이기 위한 인스턴스 프로파일
resource "aws_iam_instance_profile" "app_ec2" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app_ec2.name
}

# 장바구니 테이블 읽기/쓰기 권한 (이것도 최소권한 — cart 테이블만)
resource "aws_iam_role_policy" "dynamodb_cart" {
  name = "${var.project_name}-dynamodb-cart"
  role = aws_iam_role.app_ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.cart.arn
    }]
  })
}