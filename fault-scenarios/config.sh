#!/bin/bash
# ============================================================================
# 공통 설정 — 모든 시나리오 스크립트에서 source 해서 사용
# ============================================================================

# ----- 리전 -----
REGION="ap-northeast-2"

# ----- EC2 (앱 서버) -----
EC2_ID="i-03a20dc2630bd1d8f"

# ----- RDS 인스턴스 -----
MEMBER_DB_ID="ecommerce-portfolio-member-db"
PAYMENT_DB_ID="ecommerce-portfolio-payment-db"

# ----- 보안 그룹 -----
APP_SG_ID="sg-0ae4bbf1fa142dc40"
MEMBER_DB_SG_ID="sg-036d591bf045172ee"
PAYMENT_DB_SG_ID="sg-0c3728e29d400ede9"

# ----- DynamoDB -----
DYNAMODB_TABLE="ecommerce-portfolio-cart"

# ----- 로그 출력 함수 -----
log_info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
log_warning() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[OK]\033[0m $1"; }

# ----- AWS CLI 페이저 끄기 (출력 멈춤 방지) -----
export AWS_PAGER=""

# 색상
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
