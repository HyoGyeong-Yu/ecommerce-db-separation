# Runbook: DynamoDB IAM 권한 실패

## 증상 감지
- **알람**: `dynamodb-write-failed` (권한 거부)
- **사용자 영향**: 장바구니 상품 추가 불가
- **다른 서비스**: 회원 로그인, 결제 처리는 정상 작동 (DB 분리 설계의 장점)

---

## 진단 절차

### Step 1: CloudWatch 알람 확인
```
AWS Console → CloudWatch → Alarms
→ dynamodb-write-failed 상태 확인
```

### Step 2: 애플리케이션 로그 확인
```bash
tail -50 /var/log/app.log | grep -i "dynamodb\|cart\|permission\|access"
```
**예상 결과**: `AccessDenied` 또는 `User: arn:aws:iam::... is not authorized`

### Step 3: EC2 IAM 역할 확인
```
AWS Console → EC2 → Instances → <app-instance>
→ IAM instance profile 확인
```
**확인**: app-ec2-role이 할당되어 있는가?

### Step 4: IAM 정책 검토
```
AWS Console → IAM → Roles → app-ec2-role
→ Attached policies 확인
```
**확인**: DynamoDB 권한이 있는 정책이 포함되어 있는가?
- `dynamodb:PutItem`
- `dynamodb:GetItem`
- 리소스: `arn:aws:dynamodb:ap-northeast-2:*:table/ecommerce-portfolio-cart`

### Step 5: DynamoDB 테이블 확인
```
AWS Console → DynamoDB → Tables → ecommerce-portfolio-cart
→ 테이블 상태 및 권한 설정 검토
```

---

## 복구 절차 (예상 소요시간: 10분)

### 옵션 A: 정책 생성 및 할당 (권장)
1. AWS Console → IAM → Policies → Create policy
2. 아래 정책 생성:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:ap-northeast-2:*:table/ecommerce-portfolio-cart"
    }
  ]
}
```
3. app-ec2-role에 정책 할당

### 옵션 B: Terraform으로 수정 (최적)
1. `terraform/iam.tf` 에서 app-ec2-role 정책 검토
2. DynamoDB 권한 추가 여부 확인
3. `terraform apply` 실행

---

## 검증

- [ ] CloudWatch 알람 → OK 상태인가?
- [ ] 브라우저에서 장바구니 상품 추가 → 성공하는가?
- [ ] DynamoDB 콘솔 → ecommerce-portfolio-cart 테이블 확인
  ```
  AWS Console → DynamoDB → Tables → ecommerce-portfolio-cart
  → Items 탭 → 새로운 항목이 추가되었는가?
  ```
- [ ] 회원 DB / 결제 DB 여전히 정상 작동하는가?

---

## 근본 원인 & 재발 방지

**원인**: EC2 IAM 역할(app-ec2-role)에 DynamoDB 접근 권한이 없음

**설계 의도 (최소 권한 원칙)**:
- SSM role: EC2 원격 접속만 가능 (Secrets Manager 접근 불가)
- app-ec2-role: DynamoDB만 접근 (RDS 직접 접근 불가)
- 각 권한이 필요한 것만 명시적으로 할당

**이 장애가 증명한 것**:
- IAM 최소 권한 설계가 동작함 ✓
- 한쪽 서비스 권한 부족이 다른 DB 접근은 막지 않음 ✓

**재발 방지**:
- [ ] Terraform `iam.tf` 확인 (app-ec2-role DynamoDB 정책)
- [ ] 정기 감사 (월 1회 IAM 권한 검토)
- [ ] CI/CD에 `terraform plan` 검증 추가 (배포 전 권한 변경사항 알림)

---

## 참고: 아키텍처에서의 역할 분리

| 역할 | 권한 | 용도 |
|---|---|---|
| **ssm-ec2-role** | SSM Session Manager | 원격 접속 |
| **app-ec2-role** | DynamoDB 쓰기/읽기 | 장바구니 서비스 |
| **RDS 자격증명** | Secrets Manager 저장 | DB 연결 (IAM이 아닌 자격증명 기반) |

이렇게 분리하면 한쪽 권한 침해 또는 실수가 전체 인프라에 영향을 주지 않습니다.
