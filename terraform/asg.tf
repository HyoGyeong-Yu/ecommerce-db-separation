# ── ASG: 단일 EC2를 자동 복구되는 인스턴스 그룹으로 교체 ──

# Launch Template — "EC2를 어떻게 만들지" 설계도
# user_data 덕분에 부팅하면 앱이 알아서 설치·실행됨 (수동 git pull / export / uvicorn 불필요)
resource "aws_launch_template" "app" {
  name          = "${var.project_name}-lt"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t2.micro"

  # IMDSv2 강제 — 토큰 없는 메타데이터 접근 차단 (SSRF 자격증명 탈취 방어)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.app_ec2.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # 1. 앱 코드 받기
    dnf install -y git
    cd /home/ec2-user
    git clone https://github.com/HyoGyeong-Yu/ecommerce-db-separation.git
    cd ecommerce-db-separation/app

    # 2. 파이썬 환경 준비
    python3 -m venv venv
    ./venv/bin/pip install -r requirements.txt
    chown -R ec2-user:ec2-user /home/ec2-user/ecommerce-db-separation

    # 3. systemd 서비스 등록 — 세션 끊겨도 유지 + 죽으면 자동 재시작
    cat > /etc/systemd/system/ecommerce-api.service <<UNIT
    [Unit]
    Description=ecommerce-db-separation FastAPI
    After=network.target

    [Service]
    User=ec2-user
    WorkingDirectory=/home/ec2-user/ecommerce-db-separation/app
    Environment=AWS_REGION=${var.region}
    Environment=MEMBER_DB_SECRET=${aws_secretsmanager_secret.member_db.name}
    Environment=PAYMENT_DB_SECRET=${aws_secretsmanager_secret.payment_db.name}
    Environment=CART_TABLE=${aws_dynamodb_table.cart.name}
    ExecStart=/home/ec2-user/ecommerce-db-separation/app/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
    Restart=always
    RestartSec=3

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now ecommerce-api
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-asg-app" }
  }
}

# Auto Scaling Group — 항상 2대 유지, 부하 시 최대 4대
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  min_size            = 2
  desired_capacity    = 2
  max_size            = 4
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]

  # ELB 헬스체크 기준: /health 응답 못 하면 인스턴스 교체
  health_check_type         = "ELB"
  health_check_grace_period = 300 # pip install 시간 고려해 5분 유예

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-app"
    propagate_at_launch = true
  }
}

# CPU 평균 60% 넘으면 자동 증설 (k6 부하테스트로 2→4 검증 예정)
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}