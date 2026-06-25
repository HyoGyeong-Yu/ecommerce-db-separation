#!/bin/bash
# ============================================================================
# 공통 설정 — 모든 시나리오 스크립트가 불러옴
# ============================================================================

REGION="ap-northeast-2"
PROJECT_NAME="ecommerce-portfolio"

# RDS
MEMBER_DB_ID="${PROJECT_NAME}-member-db"
PAYMENT_DB_ID="${PROJECT_NAME}-payment-db"

# DynamoDB
DYNAMODB_TABLE="${PROJECT_NAME}-cart"

# EC2
APP_INSTANCE_ID="i-0aa36dedcbc659172"

# Security Groups
APP_SG_ID="sg-0c24b497946d0cd96"
MEMBER_DB_SG_ID="sg-03e0bc560c005b09e"
PAYMENT_DB_SG_ID="sg-0630477ff5bccd0cf"

# 색상
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
