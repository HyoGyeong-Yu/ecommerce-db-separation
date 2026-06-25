#!/bin/bash
# ============================================================================
# 시나리오 1: 회원 DB 연결 실패
# 재현: 회원 DB SG에서 앱 서버의 3306 인바운드 규칙 제거 → 연결 차단
# ============================================================================
source ./config.sh

echo "=========================================="
echo " 시나리오 1: 회원 DB 연결 실패"
echo "=========================================="

# ----- [1] 장애 전 정상 상태 확인 -----
log_info "[1단계] 장애 전 정상 상태 확인"
aws rds describe-db-instances \
  --db-instance-identifier "$MEMBER_DB_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus]' \
  --output table

log_info "현재 회원 DB SG 인바운드 규칙:"
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$MEMBER_DB_SG_ID" \
  --region "$REGION" \
  --query 'SecurityGroupRules[?!IsEgress].[SecurityGroupRuleId,FromPort,ReferencedGroupInfo.GroupId]' \
  --output table

read -p "▶ 장애를 발생시키려면 Enter... "

# ----- [2] 장애 재현: 3306 인바운드 규칙 삭제 -----
log_warning "[2단계] 장애 재현 — 회원 DB SG에서 3306 규칙 제거"

RULE_ID=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$MEMBER_DB_SG_ID" \
  --region "$REGION" \
  --query "SecurityGroupRules[?FromPort==\`3306\` && !IsEgress].SecurityGroupRuleId" \
  --output text)

echo "삭제할 규칙 ID: $RULE_ID"

aws ec2 revoke-security-group-ingress \
  --group-id "$MEMBER_DB_SG_ID" \
  --security-group-rule-ids "$RULE_ID" \
  --region "$REGION"

log_error "회원 DB 3306 인바운드 차단됨 → 앱에서 회원 DB 연결 불가"

# ----- [3] 증거 캡처 -----
log_info "[3단계] 증거 캡처 — 차단된 SG 규칙 상태"
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$MEMBER_DB_SG_ID" \
  --region "$REGION" \
  --query 'SecurityGroupRules[?!IsEgress].[SecurityGroupRuleId,FromPort,IpProtocol]' \
  --output table

echo ""
log_warning "📸 지금 EC2에서 mysql 접속 시도하면 Connection timeout 발생"
log_warning "   mysql -h <member-db-endpoint> -u admin -p"
log_warning "   → 이 에러 화면을 캡처하세요 (포트폴리오 증거)"

read -p "▶ 증거 캡처 끝났으면 복구하려면 Enter... "

# ----- [4] 복구: 규칙 다시 추가 -----
log_info "[4단계] 복구 — 3306 인바운드 규칙 재생성"
aws ec2 authorize-security-group-ingress \
  --group-id "$MEMBER_DB_SG_ID" \
  --region "$REGION" \
  --ip-permissions "IpProtocol=tcp,FromPort=3306,ToPort=3306,UserIdGroupPairs=[{GroupId=$APP_SG_ID}]"

log_success "회원 DB 3306 인바운드 규칙 복구 완료"

# ----- [5] 검증 -----
log_info "[5단계] 복구 검증 — SG 규칙 정상 확인"
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$MEMBER_DB_SG_ID" \
  --region "$REGION" \
  --query 'SecurityGroupRules[?!IsEgress].[SecurityGroupRuleId,FromPort,ReferencedGroupInfo.GroupId]' \
  --output table

log_success "✅ 시나리오 1 완료 — 회원 DB 연결 복구됨"