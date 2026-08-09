#!/bin/bash
# ⚠️ EC2(SSM 세션)에서 실행 — mysql 클라이언트와 DB 접근 SG가 필요함

source ./config.sh

echo "=========================================="
echo " 시나리오 1: 커넥션 풀 고갈 (member-db)"
echo "=========================================="

CONN_COUNT=50        # 점유할 커넥션 수
HOLD_SECONDS=600     # 각 커넥션 유지 시간(초)

# ----- DB 접속 정보 로드 (Secrets Manager) -----
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "ecommerce-portfolio/member-db" \
  --query SecretString --output text --region "$REGION")
DB_HOST=$(echo "$SECRET" | python3 -c "import sys,json;print(json.load(sys.stdin)['host'])")
DB_USER=$(echo "$SECRET" | python3 -c "import sys,json;print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo "$SECRET" | python3 -c "import sys,json;print(json.load(sys.stdin)['password'])")

# ----- [1] 장애 전 정상 상태 확인 -----
log_info "[1단계] 장애 전 정상 상태 확인"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" \
  -e "SHOW STATUS LIKE 'Threads_connected';"
log_info "현재 커넥션 수가 한 자릿수면 정상 상태"

read -p "▶ 장애를 발생시키려면 Enter... "

# ----- [2] 장애 주입: SLEEP 쿼리로 커넥션 점유 -----
log_warning "[2단계] 장애 주입 — 커넥션 ${CONN_COUNT}개 점유 (SLEEP ${HOLD_SECONDS}s)"
log_warning "주입 시각: $(date '+%F %T')  ← 타임라인 표의 '주입 시각'으로 기록"

for i in $(seq 1 "$CONN_COUNT"); do
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" \
    -e "SELECT SLEEP(${HOLD_SECONDS});" &
done

log_error "커넥션 ${CONN_COUNT}개 점유됨 → 신규 연결 실패 유도"

# ----- [3] 증거 캡처 -----
log_info "[3단계] 증거 캡처"
log_warning "📸 member API 호출 → 503 응답 화면"
log_warning "📸 payment/cart API 호출 → 200 정상 (격리 증명)"
log_warning "📸 CloudWatch DatabaseConnections 급등 그래프"
log_warning "📸 알람 member-db-high-connections In alarm 화면"

read -p "▶ 증거 캡처 끝났으면 복구하려면 Enter... "

# ----- [4] 복구: 점유 세션 일괄 KILL -----
log_info "[4단계] 복구 — SLEEP 세션 일괄 KILL"
log_info "복구 시각: $(date '+%F %T')  ← 타임라인 표의 '복구 시각'으로 기록"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -N \
  -e "SELECT CONCAT('KILL ', id, ';') FROM information_schema.processlist WHERE info LIKE '%SLEEP%';" \
  | mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS"
log_success "점유 세션 종료 완료"

# ----- [5] 검증 -----
log_info "[5단계] 복구 검증 — 커넥션 수 정상 확인"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" \
  -e "SHOW STATUS LIKE 'Threads_connected';"
log_warning "📸 알람 OK 복귀 + member API 200 화면"
log_success "✅ 시나리오 1 완료 — 커넥션 풀 정상화"