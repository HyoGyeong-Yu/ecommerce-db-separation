
source ./config.sh

echo "=========================================="
echo " 시나리오 5: AZ 장애 — Multi-AZ 자동 Failover"
echo "=========================================="

# ----- [1] 장애 전 정상 상태 확인 -----
log_info "[1단계] Multi-AZ 활성화 및 현재 AZ 확인"

MULTI_AZ=$(aws rds describe-db-instances \
  --db-instance-identifier "$MEMBER_DB_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].MultiAZ' \
  --output text)

if [ "$MULTI_AZ" != "True" ]; then
  log_error "Multi-AZ가 꺼져 있음. 먼저 terraform apply -var=\"member_db_multi_az=true\" 실행 필요"
  log_error "(전환에 10~15분 소요, 상태가 available로 돌아온 뒤 이 스크립트 재실행)"
  exit 1
fi

log_success "Multi-AZ 활성화 확인됨"
log_info "현재 주 AZ / 스탠바이 AZ:"
aws rds describe-db-instances \
  --db-instance-identifier "$MEMBER_DB_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].[DBInstanceIdentifier,AvailabilityZone,SecondaryAvailabilityZone,DBInstanceStatus]' \
  --output table

echo ""
log_warning "📸 위 테이블 캡처 — failover 전 주 AZ 위치 (핵심 비교 증거 1/2)"

read -p "▶ AZ 장애를 발생시키려면 Enter... "

# ----- [2] 장애 재현: 강제 failover -----
log_warning "[2단계] 장애 재현 — 주 인스턴스 강제 failover (AZ 장애 시뮬레이션)"

aws rds reboot-db-instance \
  --db-instance-identifier "$MEMBER_DB_ID" \
  --force-failover \
  --region "$REGION" \
  --query 'DBInstance.[DBInstanceIdentifier,DBInstanceStatus]' \
  --output table

log_error "주 인스턴스 다운 → 스탠바이로 자동 전환 진행 중 (보통 1~2분)"

# ----- [3] 증거 캡처: 자동 복구 관찰 -----
log_info "[3단계] 증거 캡처 — available 상태 복귀 대기"

aws rds wait db-instance-available \
  --db-instance-identifier "$MEMBER_DB_ID" \
  --region "$REGION"

log_success "failover 완료 — DB가 스탠바이 AZ에서 다시 서비스 중"

log_info "failover 후 주 AZ / 스탠바이 AZ (서로 뒤바뀜):"
aws rds describe-db-instances \
  --db-instance-identifier "$MEMBER_DB_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].[DBInstanceIdentifier,AvailabilityZone,SecondaryAvailabilityZone,DBInstanceStatus]' \
  --output table

echo ""
log_info "RDS 이벤트 로그 (failover 기록):"
aws rds describe-events \
  --source-identifier "$MEMBER_DB_ID" \
  --source-type db-instance \
  --duration 30 \
  --region "$REGION" \
  --query 'Events[].[Date,Message]' \
  --output table

echo ""
log_warning "📸 캡처할 것 3가지:"
log_warning "   1. 위 AZ 테이블 — 1단계와 비교해 주/스탠바이가 뒤바뀐 것 (핵심 증거 2/2)"
log_warning "   2. 위 이벤트 로그 — 'Multi-AZ instance failover started/completed'"
log_warning "   3. EC2에서 mysql 접속 — 같은 endpoint로 재접속 성공"
log_warning ""
log_warning "💡 핵심: 앱 설정(endpoint)을 하나도 안 바꿨는데 DB가 다른 AZ에서 살아남"
log_warning "   → 시나리오 1~4는 수동 복구, 이번엔 AWS가 자동 복구"

read -p "▶ 증거 캡처 끝났으면 Enter... "

# ----- [4] 복구 -----
log_info "[4단계] 복구 — failover 자체가 복구이므로 추가 조치 불필요"
log_success "서비스는 이미 정상 (자동 복구 완료)"

# ----- [5] 검증 및 정리 안내 -----
log_info "[5단계] 최종 검증"
aws rds describe-db-instances \
  --db-instance-identifier "$MEMBER_DB_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,MultiAZ,AvailabilityZone]' \
  --output table

log_success "✅ 시나리오 5 완료 — AZ 장애에도 자동 failover로 서비스 유지 확인"
echo ""
log_warning "💰 비용 절감: 캡처가 끝났으면 Multi-AZ를 꺼서 요금을 원래대로 되돌리세요"
log_warning "   cd ../terraform && terraform apply -var=\"member_db_multi_az=false\""