# Runbook: 결제 DB 연결 실패

## 증상 감지
- **알람** `payment-db-connection-failed` (RDS 커넥션 타임아웃)
- **사용자 영향** 결제 처리 불가, 주문 완료 실패
- **다른 서비스** 회원 로그인, 장바구니는 정상 작동 (DB 분리 설계의 장점)


## 진단 절차

### Step 1: CloudWatch 알람 확인

AWS Console → CloudWatch → Alarms
→ payment-db-connection-failed 상태 확인


### Step 2: EC2에서 결제 DB 연결 테스트

mysql -h <PAYMENT_DB_ENDPOINT> -u admin -p<PASSWORD> -e "SELECT 1;"

**예상 결과** timeout 또는 connection refused


### Step 3: RDS 보안그룹 확인

AWS Console → RDS → payment-db-instance
→ Security groups → Inbound rules 검토

**확인** 3306 포트가 app-sg에서 허용되는가?


### Step 4: 애플리케이션 로그 확인

tail -50 /var/log/app.log | grep -i "payment\|checkout\|order"

**예상 결과** "Payment DB connection timeout" 에러


### Step 5: 회원 DB와 비교 테스트

# 회원 DB는 정상인지 확인 (isolation 검증)
mysql -h <MEMBER_DB_ENDPOINT> -u admin -p<PASSWORD> -e "SELECT 1;"

**예상 결과** timeout 안 나옴 (회원 DB는 정상 = 장애가 결제 DB에만 국한됨)


## 복구 절차 (예상 소요시간: 5분)

1. RDS 콘솔 → payment-db-instance → Modify
2. Security groups에서 app-sg → 3306 포트 추가
3. Immediately apply
4. 1-2분 대기


## 검증

-  EC2에서 결제 DB SQL 재테스트 → "Query OK" 나오는가?
-  브라우저 결제 시도 → 성공하는가?
-  CloudWatch 알람 → OK 상태인가?
-  회원 DB / 장바구니 여전히 정상 작동하는가?


## 근본 원인 & 재발 방지

**원인** RDS SG 인바운드 규칙이 app-sg를 허용하지 않음

**Fault Isolation 검증** (이 장애가 증명한 것):
- 회원 DB 장애 ≠ 결제 DB 장애
- 한쪽 DB 문제가 다른 쪽에 영향 없음 

**재발 방지**
-  Terraform `security-groups.tf` 확인 (payment_db_sg 규칙)
-  정기 감사 (월 1회 RDS SG 규칙 검토)