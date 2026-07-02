# Runbook: EC2 인스턴스 실패 (헬스체크 실패)

## 증상 감지
- **알람** `ec2-status-check-failed` (EC2 인스턴스 상태 확인 실패)
- **사용자 영향** 모든 서비스 접근 불가 (회원 DB / 결제 DB / 장바구니)
- **근본 원인** EC2 인스턴스가 stopped 또는 terminated 상태


## 진단 절차

### Step 1: CloudWatch 알람 확인

AWS Console → CloudWatch → Alarms
→ ec2-status-check-failed 상태 확인


### Step 2: EC2 인스턴스 상태 확인

AWS Console → EC2 → Instances
→ <app-instance> 선택
→ Instance State 확인

**예상 상태**
- `stopped` 또는 `terminated`
- 상태 검사: 2/2 checks failed (또는 N/A)

### Step 3: ALB Target Group 상태 확인

AWS Console → EC2 → Load Balancers
→ Target Groups → <app-targets>
→ Targets 탭

**예상 상태**
- 타겟 EC2: Unhealthy (빨간 상태)
- Reason: "Instance has failed at least the Unhealthy Threshold number of health checks consecutively"

### Step 4: 애플리케이션 연결성 테스트

# ALB 엔드포인트로 접속 시도
curl http://<ALB_DNS_NAME>

# 또는 브라우저에서
# https://<ALB_DNS_NAME>

**예상 결과** `502 Bad Gateway` 또는 timeout

### Step 5: CloudWatch 메트릭 확인

AWS Console → CloudWatch → Metrics
→ AWS/ApplicationELB
→ TargetResponseTime, HTTPCode_Target_5XX 확인

**예상 그래프** 5xx 에러 급증


## 복구 절차 (예상 소요시간: 5-10분)

### 옵션 A: 정지된 인스턴스 재시작
1. AWS Console → EC2 → Instances
2. <app-instance> 우클릭 → Instance State → Start
3. 1-2분 대기 (부팅)
4. 인스턴스 상태 → `running`으로 전환 확인

### 옵션 B: Auto Scaling Group이 자동 교체 (권장)
- EC2가 ASG에 속해 있다면, 자동으로 unhealthy 인스턴스 감지
- 새 인스턴스 자동 시작 (Terminate → 신규 인스턴스 생성)
- 약 3-5분 소요

### 옵션 C: Terraform으로 인스턴스 재생성

cd terraform
terraform apply -target=aws_instance.app


## 검증

-  EC2 인스턴스 상태 → `running` 상태인가?
-  ALB Target Group → Healthy (녹색) 상태인가?
-  CloudWatch 알람 → OK 상태인가?
-  브라우저에서 ALB 엔드포인트 접속 → 정상 응답 (200 OK)인가?
-  모든 DB 서비스 정상 작동하는가?
  -  회원 로그인
  -  결제 처리
  -  장바구니 상품 추가


## 근본 원인 & 재발 방지

**원인** EC2 인스턴스가 중지(stopped) 또는 종료(terminated) 상태

**발생 가능 시나리오**
1. 수동 중지 (실수로 EC2 중단)
2. 하드웨어 장애
3. OS 크래시
4. 보안 이슈로 인한 자동 중지

**복구 시간 (RTO)**
- 수동 재시작: 1-2분
- ASG 자동 교체: 3-5분

**재발 방지**
-  Auto Scaling Group 설정 확인

  AWS Console → EC2 → Auto Scaling Groups
  → <app-asg> → Health Check Period: 300초 이상?
  → Desired Capacity vs Min/Max 확인
  

-  Health Check 설정 검토
 
  # Terraform 예시:
  health_check_type = "ELB"
  health_check_grace_period = 300
 

-  CloudWatch 알람 설정 확인
  -  `ec2-status-check-failed` 알람 활성화
  -  SNS 알림 정상 작동 여부
  -  Slack/이메일 통보 테스트

-  정기 감사 (주 1회 인스턴스 상태 확인)



## 참고: 단일 EC2 vs Auto Scaling Group 비교

|     구성     |    장점    |     단점     |     RTO     |
| **단일 EC2** | 간단 | 장애 시 수동 대응 필요 | 5-10분 (수동) |
| **ASG (현재)** | 자동 복구 | 약간의 복잡성 | 3-5분 (자동) |

현재 ASG 구성이 있다면, 자동으로 unhealthy 인스턴스를 감지하고 새 인스턴스를 자동 시작합니다.


## 응급 복구 체크리스트

1. EC2 인스턴스 상태 확인 (running?)
2. ALB Health Check 상태 확인 (Healthy?)
3. 애플리케이션 로그 확인 (/var/log/app.log)
4. 네트워크 연결 테스트 (DB, DynamoDB 접근 가능?)
5. 서비스 정상화 확인 (회원 / 결제 / 장바구니)
6. 장애 원인 분석 및 기록
7. 예방 조치 검토
