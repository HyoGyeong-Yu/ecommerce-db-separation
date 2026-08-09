#!/bin/bash
# ⚠️ EC2(SSM 세션)에서 실행 — mysql 클라이언트와 DB 접근 SG가 필요함

source ./config.sh

echo "=========================================="
echo " 시나리오 2: 슬로우 쿼리 폭주 (member-db)"
echo "=========================================="

WORKERS=10           # 병렬 실행 개수

# ----- DB 접속 정보 로드 (Secrets Manager) -----
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "ecommerce-portfolio/member-db" \
  --query SecretString --output text --region "$REGION")
DB_HOST=$(echo "$SECRET" | python3 -c "import sys,json;print(json.load(sys.stdin)['host'])")
DB_USER=$(echo "$SECRET" | python3 -c "import sys,json;print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo "$SECRET" | python3 -c "import sys,json;print(json.load(sys.stdin)['password'])")

# ----- [0] 부하용 테이블 준비 (없으면 생성 + 1만 행 시딩) -----
# ⚠️ 이 블록은 AWS 리소스 삭제 이후 추가되어 실행 검증 미완료 (재구축 시 검증 필요)
log_info "[0단계] load_test 테이블 준비 — 없으면 생성"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" member_db -e "
CREATE TABLE IF NOT EXISTS load_test (
  id INT PRIMARY KEY,
  pad VARCHAR(100)
);
INSERT IGNORE INTO load_test (id, pad)
SELECT n, REPEAT('x', 100) FROM (
  SELECT a.N + b.N*10 + c.N*100 + d.N*1000 + 1 AS n
  FROM (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
  CROSS JOIN (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
  CROSS JOIN (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c
  CROSS JOIN (SELECT 0 AS N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
        UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) d
) t;
SELECT COUNT(*) AS load_test_rows FROM load_test;"
log_success "load_test 준비 완료 (인덱스 없는 컬럼 조인용 — 1만 행)"

# ----- [1] 장애 전 정상 상태 확인 -----
log_info "[1단계] 장애 전 정상 상태 확인 — CPU 및 실행 중 쿼리"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" \
  -e "SELECT id, user, time, LEFT(info,60) AS query FROM information_schema.processlist WHERE command <> 'Sleep';"

read -p "▶ 장애를 발생시키려면 Enter... "

# ----- [2] 장애 주입: 무인덱스 카티전 조인 -----
log_warning "[2단계] 장애 주입 — 카티전 조인 쿼리 ${WORKERS}개 병렬 실행"
log_warning "주입 시각: $(date '+%F %T')  ← 타임라인 표의 '주입 시각'으로 기록"

for i in $(seq 1 "$WORKERS"); do
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" member_db \
    -e "SELECT COUNT(*) FROM load_test a JOIN load_test b ON a.id <> b.id;" &
done

log_error "슬로우 쿼리 실행됨 → CPU 급등 유도"

# ----- [3] 증거 캡처 -----
log_info "[3단계] 증거 캡처"
log_warning "📸 CloudWatch CPUUtilization 급등 그래프"
log_warning "📸 알람 member-db-cpu-high In alarm 화면"
log_warning "📸 SHOW FULL PROCESSLIST — 장기 실행 쿼리 목록"
log_warning "📸 EXPLAIN 결과 — 풀스캔 확인"

read -p "▶ 증거 캡처 끝났으면 복구하려면 Enter... "

# ----- [4] 복구: 장기 실행 세션 일괄 KILL -----
log_info "[4단계] 복구 — 60초 이상 실행 중인 세션 KILL"
log_info "복구 시각: $(date '+%F %T')  ← 타임라인 표의 '복구 시각'으로 기록"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -N \
  -e "SELECT CONCAT('KILL ', id, ';') FROM information_schema.processlist WHERE user='${DB_USER}' AND time > 60;" \
  | mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS"
log_success "장기 실행 세션 종료 완료"

# ----- [5] 검증 + 잔여 세션 확인 (필수!) -----
log_info "[5단계] 잔여 세션 확인 — 아래 표가 비어 있어야 정상 종료"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" \
  -e "SELECT id, user, time, LEFT(info,60) AS query FROM information_schema.processlist WHERE time > 60;"
log_warning "※ 잔여 세션 방치 시 CPU 100% 지속 (2026-08-01 실제 발생 — 런북 02 사후 회고 참조)"
log_warning "📸 CPU 하강 그래프 + 알람 OK 복귀 화면"
log_success "✅ 시나리오 2 완료 — CPU 정상화"