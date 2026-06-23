# 최신 Amazon Linux 2023 AMI ID 자동 조회
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# 앱 서버 (3개 DB 연결 허브 / 테스트용)
resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t2.micro" # Free Tier
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app_ec2.name
  tags = { Name = "${var.project_name}-app" }
}
