#!/bin/bash
# ⚠️ 로컬 또는 EC2에서 실행 가능 (AWS CLI만 필요)
# ⚠️ 용량 변경(Provisioned ↔ On-demand)은 CLI가 아니라 Terraform으로 수행
#    → CLI로 바꾸면 Terraform state 불일치 발생 (2026-08-01 실제 경험)

source ./config.sh

echo "=========================================="
echo " 시나리오 3: DynamoDB 쓰기 스로틀링 (cart)"
echo "=========================================="

WORKERS=5            # 병렬 주입 프로세스 수
ROUNDS=40            # 프로세스당 batch-write 반복 횟수 (25건/회)

# ----- [1] 장애 전 정상 상태 확인 -----
log_info "[1단계] 장애 전 정상 상태 확인 — 테이블 용량 모드"
aws dynamodb describe-table \
  --table-name "$DYNAMODB_TABLE" \
  --region "$REGION" \
  --query 'Table.[TableName,BillingModeSummary.BillingMode,ProvisionedThroughput.WriteCapacityUnits]' \
  --output table

log_warning "준비: dynamodb_cart.tf에서 billing_mode를 PROVISIONED(WCU 1)로 변경 후 terraform apply"
read -p "▶ WCU 1 적용 완료됐으면 Enter... "

# ----- [2] 장애 주입: batch-write 폭주 -----
log_warning "[2단계] 장애 주입 — batch-write ${WORKERS}개 병렬 x ${ROUNDS}회 (25건/회)"
log_warning "주입 시각: $(date '+%F %T')  ← 타임라인 표의 '주입 시각'으로 기록"
log_info "※ 초반 1~2분은 버스트 용량에 흡수될 수 있음 — THROTTLED 뜰 때까지 지속 (2026-08-01 1차 주입 무효 경험)"

inject_worker() {
  local wid=$1
  for r in $(seq 1 "$ROUNDS"); do
    # 25건 배치 JSON 생성
    ITEMS=$(python3 -c "
import json
items = [{'PutRequest': {'Item': {
  'user_id': {'S': f'throttle-w${wid}-r${r}-u{i}'},
  'product_id': {'S': f'prod-{i}'}
}}} for i in range(25)]
print(json.dumps({'$DYNAMODB_TABLE': items}))
")
    RESULT=$(aws dynamodb batch-write-item \
      --request-items "$ITEMS" \
      --region "$REGION" 2>&1)
    if echo "$RESULT" | grep -q "ProvisionedThroughputExceededException"; then
      log_error "[worker ${wid}] THROTTLED 발생: $(date '+%F %T')  ← 타임라인 표의 '첫 THROTTLED'로 기록"
    fi
  done
}

for w in $(seq 1 "$WORKERS"); do
  inject_worker "$w" &
done
wait

log_error "주입 종료: $(date '+%F %T')"

# ----- [3] 증거 캡처 -----
log_info "[3단계] 증거 캡처"
log_warning "📸 터미널의 THROTTLED 에러 출력"
log_warning "📸 CloudWatch WriteThrottleEvents 메트릭 그래프"
log_warning "📸 알람 ecommerce-portfolio-dynamodb-write-throttle In alarm 화면"
log_warning "📸 member/payment API 정상 응답 (격리 증명)"

read -p "▶ 증거 캡처 끝났으면 복구하려면 Enter... "

# ----- [4] 복구: Terraform으로 On-demand 복귀 -----
log_info "[4단계] 복구 — dynamodb_cart.tf를 PAY_PER_REQUEST로 되돌린 후 terraform apply"
log_info "복구 시각 기록: apply 완료 시각을 타임라인 표의 '복구 시각'으로 기록"
read -p "▶ terraform apply 완료됐으면 Enter... "

# ----- [5] 검증 -----
log_info "[5단계] 복구 검증 — 용량 모드 및 쓰기 정상 확인"
aws dynamodb describe-table \
  --table-name "$DYNAMODB_TABLE" \
  --region "$REGION" \
  --query 'Table.[TableName,BillingModeSummary.BillingMode]' \
  --output table

aws dynamodb put-item \
  --table-name "$DYNAMODB_TABLE" \
  --item '{"user_id":{"S":"recovery-check"},"product_id":{"S":"prod-1"}}' \
  --region "$REGION" \
  && log_success "쓰기 정상화 확인: $(date '+%F %T')"

log_warning "📸 알람 OK 복귀 화면 (또는 알람 히스토리 텍스트 보존)"
log_success "✅ 시나리오 3 완료 — On-demand 복귀 및 쓰기 정상화"
