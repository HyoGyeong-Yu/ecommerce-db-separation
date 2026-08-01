# Runbook: AZ 장애 — Multi-AZ 자동 Failover

## 증상 감지
- **알람**: RDS 이벤트 `Multi-AZ instance failover started` (SNS 이벤트 구독 시 메일 수신)
- **사용자 영향**: 회원 기능이 1~2분간 일시 중단 후 **자동 복구** (로그인 재시도 시 정상)
- **다른 서비스**: 결제 DB / 장바구니는 영향 없음 (DB 분리 설계의 장점)
- **시나리오 1~4와의 차이**: 사람이 복구하는 것이 아니라 **AWS가 스탠바이 AZ로 자동 전환**함. 운영자의 역할은 복구 작업이 아니라 **전환이 정상적으로 끝났는지 검증**하는 것

---

## 진단 절차

### Step 1: Multi-AZ 구성 및 현재 AZ 확인
```bash
aws rds describe-db-instances \
  --db-instance-identifier ecommerce-portfolio-member-db \
  --region ap-northeast-2 \
  --query 'DBInstances[0].[MultiAZ,AvailabilityZone,SecondaryAvailabilityZone,DBInstanceStatus]' \
  --output table

# 확인할 것:
# - MultiAZ: True 인가?
# - AvailabilityZone: 장애 전 주 AZ (예: ap-northeast-2a)
# - SecondaryAvailabilityZone: 스탠바이 위치 (예: ap-northeast-2c)
```

### Step 2: RDS 이벤트 로그 확인 (failover 발생 여부)
```bash
aws rds describe-events \
  --source-identifier ecommerce-portfolio-member-db \
  --source-type db-instance \
  --duration 30 \
  --region ap-northeast-2 \
  --query 'Events[].[Date,Message]' \
  --output table

# 예상 결과:
# "Multi-AZ instance failover started"
# "Multi-AZ instance failover completed"
# → 이 두 줄이 있으면 failover가 발생했고 이미 완료된 것
```

### Step 3: 현재 DB 상태 확인
```bash
aws rds describe-db-instances \
  --db-instance-identifier ecommerce-portfolio-member-db \
  --region ap-northeast-2 \
  --query 'DBInstances[0].[DBInstanceStatus,AvailabilityZone]' \
  --output table

# 예상 결과:
# - DBInstanceStatus: available
# - AvailabilityZone: Step 1과 비교해 주 AZ가 뒤바뀌어 있음
#   (예: 2a → 2c) → 스탠바이가 주 역할을 넘겨받았다는 증거
```

### Step 4: EC2에서 연결 테스트 (endpoint 변경 없음 확인)
```bash
# SSM Session Manager로 EC2 접속
aws ssm start-session --target <EC2_INSTANCE_ID>

# 장애 전과 동일한 endpoint로 연결 시도
mysql -h <MEMBER_DB_ENDPOINT> -u admin -p -e "SELECT NOW();"

# 예상 결과:
# 정상 응답 → 앱 설정을 하나도 바꾸지 않았는데 연결됨
# (RDS가 DNS를 스탠바이로 자동 전환했기 때문)
```

---

## 복구 절차 (예상 소요시간: 0분 — 자동 복구)

**이 시나리오에서 운영자가 수행할 복구 작업은 없다.**
Failover 자체가 복구이며, 1~2분 내에 자동 완료된다. 운영자는 아래만 수행한다.

1. [ ] RDS 이벤트 로그에서 `failover completed` 확인 (진단 Step 2)
2. [ ] DB 상태 `available` 확인 (진단 Step 3)
3. [ ] 앱 연결 정상 확인 (진단 Step 4)
4. [ ] 스탠바이 재구성 확인 — failover 후 RDS가 기존 주 AZ에 새 스탠바이를 자동 재생성함
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier ecommerce-portfolio-member-db \
     --region ap-northeast-2 \
     --query 'DBInstances[0].SecondaryAvailabilityZone' \
     --output text
   # 값이 존재하면 다음 AZ 장애에도 대비 완료된 상태
   ```

---

## 검증

- [ ] **AZ 전환 확인** (핵심 증거)
  ```
  장애 전: 주 AZ = ap-northeast-2a / 스탠바이 = ap-northeast-2c
  장애 후: 주 AZ = ap-northeast-2c / 스탠바이 = ap-northeast-2a
  → 서로 뒤바뀜 = failover 성공
  ```

- [ ] **RDS 이벤트 로그**
  ```
  "Multi-AZ instance failover started" → "completed" 기록 존재
  ```

- [ ] **동일 endpoint로 재연결 성공**
  ```bash
  mysql -h <MEMBER_DB_ENDPOINT> -u admin -p -e "SELECT 1;"
  # 앱 코드/설정 변경 0건으로 정상 응답
  ```

- [ ] **다른 DB 정상 작동 확인** (분리 설계 검증)
  ```
  - 결제 DB 연결 테스트 ✓
  - 장바구니 담기 시도 (DynamoDB) ✓
  ```

---

## 근본 원인 & 재발 방지

### 근본 원인
- 가용 영역(AZ) 단위 장애: 데이터센터 전원/네트워크 문제 등으로 주 인스턴스가 위치한 AZ 전체가 사용 불가
- 단일 AZ 구성이었다면 → 회원 DB 완전 중단, 스냅샷 복원 전까지 수동 복구 불가 (RTO 수십 분 이상)

### 설계상 이점 (이번 장애에서 드러난 것)
- Multi-AZ 동기 복제 덕분에 데이터 유실 없이(RPO ≈ 0) 스탠바이로 전환
- DNS 자동 전환으로 앱 설정 변경 불필요 → RTO 1~2분
- 시나리오 1~4의 "탐지 후 수동 복구"와 달리, 이 계층의 장애는 **구조가 스스로 복구**함

### 재발 방지 조치
- [ ] **Terraform 코드 확인**
  ```hcl
  # terraform/rds_member.tf
  multi_az = var.member_db_multi_az
  # 이 프로젝트에서는 비용 문제로 시나리오 검증 시에만 true
  # 실무라면 결제 DB부터 상시 true 적용
  ```
- [ ] **RDS 이벤트 구독 설정** — failover 발생 시 SNS로 즉시 통지받도록 이벤트 구독 추가
- [ ] **정기 failover 훈련** — 분기 1회 강제 failover로 전환 시간(RTO) 측정 및 기록

---

## 참고: Multi-AZ가 이 장애를 제한한 이유

| 구조 | AZ 장애 시 영향 |
|---|---|
| **단일 AZ 구조** | 회원 DB 완전 중단 → 스냅샷 복원까지 수동 복구 (RTO 수십 분~수 시간) |
| **Multi-AZ 구조 (본 시나리오)** | 1~2분 내 스탠바이 AZ로 자동 전환 → 운영자 개입 불필요 |

시나리오 1~4가 **Fault Isolation**(장애 범위 최소화)을 실증했다면,
이 시나리오는 **High Availability**(장애에도 스스로 살아남는 구조)를 실증합니다.