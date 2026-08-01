# Runbook: 회원 DB 연결 실패

## 증상 감지
- **알람**: `member-db-connection-failed` (RDS 커넥션 타임아웃)
- **사용자 영향**: 회원 로그인 불가, 프로필 조회 불가
- **다른 서비스**: 결제 DB / 장바구니는 정상 작동 (DB 분리 설계의 장점)

---

## 진단 절차

### Step 1: CloudWatch 알람 확인
```
AWS Console → CloudWatch → Alarms
→ member-db-connection-failed 알람 상태 확인
→ SNS 알림 수신 로그 검토
```

### Step 2: EC2에서 회원 DB 연결 테스트
```bash
# SSM Session Manager로 EC2 접속
aws ssm start-session --target <EC2_INSTANCE_ID>

# 회원 DB 엔드포인트로 직접 연결 시도
mysql -h <MEMBER_DB_ENDPOINT> -u admin -p<PASSWORD> -e "SELECT 1;"

# 예상 결과:
# - timeout 또는 "Connection refused" → 네트워크 차단
# - "access denied" → 자격증명 문제 (이는 연결 가능하다는 증거)
```

### Step 3: RDS 보안그룹 확인
```
AWS Console → RDS → Instances → member-db-instance
→ Connectivity & security 탭
→ Security groups 확인
→ Inbound rules 검토
  ✓ 3306 포트가 EC2 보안그룹(app-sg)에서 허용되는가?
```

### Step 4: EC2 애플리케이션 로그 확인
```bash
# SSM Session Manager 세션에서
tail -50 /var/log/app.log | grep -i "member\|db\|connection\|error"

# 또는 PHP-FPM 에러 로그
tail -50 /var/log/php-fpm/error.log
```

### Step 5: VPC 네트워크 경로 확인
```
AWS Console → VPC → Network ACLs
→ EC2가 속한 Subnet의 NACL 확인
→ Outbound 규칙 검토 (3306 포트 허용?)

AWS Console → VPC → Route Tables
→ EC2 Subnet의 Route Table 확인
→ DB가 있는 Subnet으로의 경로 설정 확인
```

---

## 복구 절차 (예상 소요시간: 5분)

1. [ ] **AWS Console 로그인** → RDS 대시보드
2. [ ] **member-db-instance 선택** → Modify 버튼 클릭
3. [ ] **Security groups 섹션** 수정
   - 현재 할당된 보안그룹 확인
   - Inbound rule 추가: `3306 / TCP / Source: app-sg`
4. [ ] **Immediately apply** 선택 (재부팅 필요 없음)
5. [ ] 변경사항 적용 완료 대기 (약 1-2분)

### 복구 후 연결 재테스트
```bash
# EC2에서 다시 시도
mysql -h <MEMBER_DB_ENDPOINT> -u admin -p<PASSWORD> -e "SELECT 1;"

# 예상 결과:
# Query OK, 0 rows affected ✓
```

---

## 검증

- [ ] **Direct SQL 테스트**
  ```bash
  mysql -h <MEMBER_DB_ENDPOINT> -u admin -p<PASSWORD> -e "SELECT COUNT(*) FROM users;"
  # 정상: 행 개수 반환
  ```

- [ ] **브라우저에서 로그인 시도**
  - EC2 공개 IP 또는 ALB 엔드포인트 접속
  - 회원 계정으로 로그인 성공 여부 확인

- [ ] **CloudWatch 알람 상태 확인**
  ```
  AWS Console → CloudWatch → Alarms
  → member-db-connection-failed 상태: OK (green)
  ```

- [ ] **다른 DB 정상 작동 확인** (분리 설계 검증)
  ```
  - 장바구니 담기 시도 (DynamoDB) ✓
  - 결제 DB 연결 테스트 (결제 정보 조회) ✓
  ```

---

## 근본 원인 & 재발 방지

### 근본 원인
- RDS 보안그룹의 인바운드 규칙이 EC2 보안그룹을 명시적으로 허용하지 않음
- EC2 → 회원 DB 간 네트워크 경로가 Security Group 레벨에서 차단됨

### 설계상 이점 (이번 장애에서 드러난 것)
- 회원 DB 장애 = 회원 기능만 영향받음
- 결제 DB와 장바구니는 완전히 독립적 → 다른 사용자는 서비스 이용 가능
- 이것이 DB 분리 아키텍처의 핵심 목표 달성

### 재발 방지 조치
- [ ] **Terraform 코드 검토**
  - `terraform/security-groups.tf` 확인
  - member_db_sg 인바운드 규칙에 app_sg 명시 여부 확인
  ```hcl
  # 예시:
  resource "aws_security_group_rule" "member_db_from_app" {
    type              = "ingress"
    from_port         = 3306
    to_port           = 3306
    protocol          = "tcp"
    security_group_id = aws_security_group.member_db_sg.id
    source_security_group_id = aws_security_group.app_sg.id
  }
  ```

- [ ] **배포 후 자동 검증**
  - Terraform apply 후 RDS SG 규칙 자동 검증 스크립트 추가
  
- [ ] **정기 감사**
  - 월 1회 RDS 보안그룹 규칙 검토
  - 불필요한 규칙 정리

---

## 참고: DB 분리 설계가 이 장애를 제한한 이유

| 구조 | 회원DB 장애 영향 |
|---|---|
| **단일 DB 구조** | 회원 기능 + 결제 기능 + 장바구니 모두 사용 불가 |
| **DB 분리 구조 (현재)** | 회원 기능만 불가 → 다른 사용자는 계속 쇼핑/결제 가능 |

이것이 이 아키텍처의 **Fault Isolation** 설계 원칙입니다.
