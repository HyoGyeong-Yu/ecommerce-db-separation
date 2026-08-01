
source ./config.sh

echo "=========================================="
echo " 시나리오 4: EC2 접근 불가"
echo "=========================================="

# ----- [1] 장애 전 정상 상태 확인 -----
log_info "[1단계] 장애 전 EC2 정상 상태 확인"
aws ec2 describe-instances \
  --instance-ids "$EC2_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress]' \
  --output table

log_info "현재 EC2 상태 체크 알람 상태:"
aws cloudwatch describe-alarms \
  --alarm-names "ecommerce-portfolio-ec2-status-check-failed" \
  --region "$REGION" \
  --query 'MetricAlarms[0].[AlarmName,StateValue]' \
  --output table

read -p "▶ 장애를 발생시키려면 Enter... "

# ----- [2] 장애 재현: EC2 중지 -----
log_warning "[2단계] 장애 재현 — 앱 서버 EC2 중지"
aws ec2 stop-instances \
  --instance-ids "$EC2_ID" \
  --region "$REGION" \
  --query 'StoppingInstances[0].[InstanceId,CurrentState.Name]' \
  --output table

log_info "EC2 중지 진행 중... (stopped 상태까지 대기)"
aws ec2 wait instance-stopped \
  --instance-ids "$EC2_ID" \
  --region "$REGION"

log_error "EC2 중지 완료 → 서비스 접근 불가"

# ----- [3] 증거 캡처 -----
log_info "[3단계] 증거 캡처 — EC2 중지 상태 확인"
aws ec2 describe-instances \
  --instance-ids "$$EC2_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name]' \
  --output table

echo ""
log_warning "⏰ CloudWatch 알람은 1~2분 후 ALARM 상태로 바뀜"
log_warning "📸 캡처할 것 3가지:"
log_warning "   1. EC2 콘솔 — 인스턴스 stopped 상태"
log_warning "   2. CloudWatch — ecommerce-portfolio-ec2-status-check-failed 알람이 ALARM(빨강)으로"
log_warning "   3. 이메일 — SNS 알람 메일 도착"

echo ""
log_info "알람 상태 다시 확인 (1~2분 후 실행 권장):"
log_info "aws cloudwatch describe-alarms --alarm-names ecommerce-portfolio-ec2-status-check-failed --region $REGION --query 'MetricAlarms[0].StateValue'"

read -p "▶ 증거 캡처 끝났으면 복구하려면 Enter... "

# ----- [4] 복구: EC2 다시 시작 -----
log_info "[4단계] 복구 — EC2 다시 시작"
aws ec2 start-instances \
  --instance-ids "$EC2_ID" \
  --region "$REGION" \
  --query 'StartingInstances[0].[InstanceId,CurrentState.Name]' \
  --output table

log_info "EC2 시작 진행 중... (running 상태까지 대기)"
aws ec2 wait instance-running \
  --instance-ids "$EC2_ID" \
  --region "$REGION"

log_success "EC2 재시작 완료"

# ----- [5] 검증 -----
log_info "[5단계] 복구 검증 — EC2 정상 + 알람 OK 복귀"
aws ec2 describe-instances \
  --instance-ids "$EC2_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress]' \
  --output table

echo ""
log_warning "⏰ 알람은 몇 분 후 OK로 돌아옴"
log_warning "📸 알람이 OK로 복귀한 화면도 캡처하면 '복구 검증' 증거 완성"

log_success "✅ 시나리오 4 완료 — EC2 복구됨"