#!/bin/bash
# ============================================================================
# 시나리오 3: DynamoDB 쓰기 실패 (IAM 권한 문제)
# 재현: EC2의 IAM Role에서 DynamoDB 쓰기 권한 제거 → AccessDenied
# 포인트: 최소권한(least-privilege)이 실제로 작동함을 증명
# ============================================================================
source ./config.sh

# IAM Role 이름 (terraform 기준)
IAM_ROLE_NAME="${PROJECT_NAME}-app-role"
POLICY_NAME="dynamodb-cart-access"

echo "=========================================="
echo " 시나리오 3: DynamoDB 쓰기 실패 (IAM)"
echo "=========================================="

# ----- [1] 장애 전 정상 상태 확인 -----
log_info "[1단계] DynamoDB 테이블 정상 확인"
aws dynamodb describe-table \
  --table-name "$DYNAMODB_TABLE" \
  --region "$REGION" \
  --query 'Table.[TableName,TableStatus]' \
  --output table

log_info "현재 IAM Role에 붙은 인라인 정책 목록:"
aws iam list-role-policies \
  --role-name "$IAM_ROLE_NAME" \
  --query 'PolicyNames' \
  --output table

echo ""
log_warning "📸 EC2에서 정상 쓰기 테스트 먼저 (성공 화면 캡처):"
log_warning "   aws dynamodb put-item --table-name $DYNAMODB_TABLE \\"
log_warning "     --item '{\"user_id\":{\"S\":\"u1\"},\"product_id\":{\"S\":\"p1\"}}'"

read -p "▶ 장애를 발생시키려면 Enter... "

# ----- [2] 장애 재현: DynamoDB 정책 백업 후 삭제 -----
log_warning "[2단계] 장애 재현 — IAM Role에서 DynamoDB 정책 제거"

# 현재 정책 백업 (복구용)
log_info "정책 백업 중... (dynamodb_policy_backup.json)"
aws iam get-role-policy \
  --role-name "$IAM_ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --region "$REGION" \
  --query 'PolicyDocument' > dynamodb_policy_backup.json 2>/dev/null

if [ -s dynamodb_policy_backup.json ]; then
  log_success "백업 완료: dynamodb_policy_backup.json"
  cat dynamodb_policy_backup.json
else
  log_error "정책 이름이 다를 수 있음. 위의 정책 목록에서 실제 이름 확인 후"
  log_error "스크립트 상단 POLICY_NAME 값을 수정하세요."
  exit 1
fi

# 정책 삭제 → 권한 제거
aws iam delete-role-policy \
  --role-name "$IAM_ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --region "$REGION"

log_error "DynamoDB 권한 제거됨 → 쓰기 시도 시 AccessDeniedException"

# ----- [3] 증거 캡처 -----
log_info "[3단계] 증거 캡처 — 정책 제거 확인"
aws iam list-role-policies \
  --role-name "$IAM_ROLE_NAME" \
  --query 'PolicyNames' \
  --output table

echo ""
log_warning "⚠️ IAM 권한 변경은 반영에 수 초~1분 걸림"
log_warning "📸 EC2에서 다시 put-item 시도 → AccessDeniedException 캡처:"
log_warning "   aws dynamodb put-item --table-name $DYNAMODB_TABLE \\"
log_warning "     --item '{\"user_id\":{\"S\":\"u2\"},\"product_id\":{\"S\":\"p2\"}}'"
log_warning ""
log_warning "💡 이 에러가 핵심 증거 — '최소권한이 실제로 차단함'을 보여줌"

read -p "▶ 증거 캡처 끝났으면 복구하려면 Enter... "

# ----- [4] 복구: 정책 다시 붙이기 -----
log_info "[4단계] 복구 — 백업한 정책 재적용"
aws iam put-role-policy \
  --role-name "$IAM_ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document file://dynamodb_policy_backup.json \
  --region "$REGION"

log_success "DynamoDB 정책 복구 완료"

# ----- [5] 검증 -----
log_info "[5단계] 복구 검증 — 정책 목록 확인"
aws iam list-role-policies \
  --role-name "$IAM_ROLE_NAME" \
  --query 'PolicyNames' \
  --output table

log_success "✅ 시나리오 3 완료 — DynamoDB 쓰기 권한 복구됨"
log_warning "📸 EC2에서 put-item 재시도 → 다시 성공하는 화면 캡처"