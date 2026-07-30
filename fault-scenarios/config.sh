#!/bin/bash
# ============================================================================
# 공통 설정 — 모든 시나리오 스크립트에서 source 해서 사용
# ⚠️ terraform apply로 재구축할 때마다 EC2_ID와 SG_ID 3개는 새 값으로 교체 필요
# ============================================================================

# ----- 리전 -----
REGION="ap-northeast-2"

# ----- EC2 (앱 서버) -----
EC2_ID="i-0b4b194bb11dc9e48"

# ----- RDS 인스턴스 -----
MEMBER_DB_ID="ecommerce-portfolio-member-db"
PAYMENT_DB_ID="ecommerce-portfolio-payment-db"

# ----- 보안 그룹 -----
APP_SG_ID="sg-0ea06dd66c0fb3298"
MEMBER_DB_SG_ID="sg-01c899ab067f22505"
PAYMENT_DB_SG_ID="sg-0fe2f84a23b216c86"

# ----- DynamoDB -----
DYNAMODB_TABLE="ecommerce-portfolio-cart"

# ----- AWS CLI 페이저 끄기 (출력 멈춤 방지) -----
export AWS_PAGER=""

# ----- 색상 & 로그 출력 함수 -----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
