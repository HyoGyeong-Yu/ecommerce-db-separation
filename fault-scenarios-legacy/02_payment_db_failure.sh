
source ./config.sh

echo "=========================================="
echo " 시나리오 2: 결제 DB 연결 실패"
echo "=========================================="

# ----- [1] 장애 전 정상 상태 확인 -----
log_info "[1단계] 장애 전 정상 상태 확인"
aws rds describe-db-instances \
  --db-instance-identifier "$PAYMENT_DB_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus]' \
  --output table

log_info "현재 결제 DB SG 인바운드 규칙:"
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$PAYMENT_DB_SG_ID" \
  --region "$REGION" \
  --query 'SecurityGroupRules[?!IsEgress].[SecurityGroupRuleId,FromPort,ReferencedGroupInfo.GroupId]' \
  --output table

read -p "▶ 장애를 발생시키려면 Enter... "

# ----- [2] 장애 재현: 3306 인바운드 규칙 삭제 -----
log_warning "[2단계] 장애 재현 — 결제 DB SG에서 3306 규칙 제거"

RULE_ID=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$PAYMENT_DB_SG_ID" \
  --region "$REGION" \
  --query "SecurityGroupRules[?FromPort==\`3306\` && !IsEgress].SecurityGroupRuleId" \
  --output text)

echo "삭제할 규칙 ID: $RULE_ID"

aws ec2 revoke-security-group-ingress \
  --group-id "$PAYMENT_DB_SG_ID" \
  --security-group-rule-ids "$RULE_ID" \
  --region "$REGION"

log_error "결제 DB 3306 인바운드 차단됨 → 앱에서 결제 DB 연결 불가"

# ----- [3] 증거 캡처 + 장애 격리 확인 -----
log_info "[3단계] 증거 캡처 — 결제 DB는 차단, 회원 DB는 정상"

echo ""
log_warning "📸 결제 DB SG (3306 차단됨):"
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$PAYMENT_DB_SG_ID" \
  --region "$REGION" \
  --query 'SecurityGroupRules[?!IsEgress].[SecurityGroupRuleId,FromPort,IpProtocol]' \
  --output table

echo ""
log_success "📸 회원 DB SG (정상 유지 — 장애 격리!):"
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$MEMBER_DB_SG_ID" \
  --region "$REGION" \
  --query 'SecurityGroupRules[?!IsEgress].[SecurityGroupRuleId,FromPort,ReferencedGroupInfo.GroupId]' \
  --output table

echo ""
log_warning "💡 핵심 증거: 결제 DB는 죽었지만 회원 DB는 살아있음"
log_warning "   → DB를 분리했기 때문에 결제 장애가 회원 로그인에 영향 안 줌"
log_warning "   → 결제 DB 연결 시도 시 Connection timeout 화면 캡처하세요"

read -p "▶ 증거 캡처 끝났으면 복구하려면 Enter... "

# ----- [4] 복구 -----
log_info "[4단계] 복구 — 3306 인바운드 규칙 재생성"
aws ec2 authorize-security-group-ingress \
  --group-id "$PAYMENT_DB_SG_ID" \
  --region "$REGION" \
  --ip-permissions "IpProtocol=tcp,FromPort=3306,ToPort=3306,UserIdGroupPairs=[{GroupId=$APP_SG_ID}]"

log_success "결제 DB 3306 인바운드 규칙 복구 완료"

# ----- [5] 검증 -----
log_info "[5단계] 복구 검증"
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$PAYMENT_DB_SG_ID" \
  --region "$REGION" \
  --query 'SecurityGroupRules[?!IsEgress].[SecurityGroupRuleId,FromPort,ReferencedGroupInfo.GroupId]' \
  --output table

log_success "✅ 시나리오 2 완료 — 결제 DB 연결 복구됨"