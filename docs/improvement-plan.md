# 이커머스 DB 분리 포트폴리오 — 실무형 개선 실행 계획

목표: "인위적 장애 재현"에서 → **"실제 트래픽 위에서 장애를 감지·격리·복구하고 숫자로 증명"**으로 업그레이드.

작업 순서: Phase 1 → 2 → 3 → 4 → 5 → 6. (1~2가 효과 최대, 먼저)

---

## Phase 1. 미니 API 서버 + 부하 테스트 (예상 2~3일)

### 왜
지금은 mysql CLI 접속 확인이라 "격리"가 실증이 안 됨. 실제 HTTP 트래픽이 흐르는 상태에서 장애를 주입해야 함.

### 할 일
1. Flask(또는 FastAPI)로 API 3개 작성 — 각각 자기 DB만 사용
   - `GET /members/{id}` → member-db (RDS)
   - `POST /payments` → payment-db (RDS)
   - `PUT /cart/{user_id}` → DynamoDB
   - 헬스체크: `GET /health` (ALB용, Phase 2에서 사용)
2. EC2에 systemd 서비스로 등록 (`ecommerce-api.service`) → 재부팅에도 자동 실행
3. 로컬(또는 별도 EC2)에서 k6 설치, 부하 스크립트 작성
   - 3개 엔드포인트에 동시 트래픽 (예: 초당 20req, 5분)
4. **정상 상태 베이스라인 측정** → 그다음 장애 주입 실험

### 증거 캡처 목록
- [ ] `systemctl status ecommerce-api` — 서비스 기동 상태
- [ ] 정상 상태 k6 결과 요약 (3개 API 모두 성공률 100%, p95 응답시간)
- [ ] **핵심 컷**: member-db 장애 중 k6 결과 — member API 실패율 급등 vs payment/cart 성공률 유지 (이 캡처 1장이 프로젝트의 얼굴)
- [ ] CloudWatch에서 같은 시간대 지표 그래프 (겹쳐 보이게)
- [ ] API 코드 GitHub 커밋 링크

---

## Phase 2. SPOF 해소 — ALB + Auto Scaling (예상 2~3일)

### 왜
시나리오 4에서 "EC2가 SPOF"라고 실증까지 해놓고 방치한 상태. **문제 발견 → 개선 → 재검증** 스토리로 완성해야 실무 서사가 됨.

### 할 일
1. Terraform에 추가: ALB + Target Group + Launch Template + ASG (min 2 / max 3, 2개 AZ 분산)
2. Launch Template의 user_data에 API 자동 설치 스크립트 포함
3. 시나리오 4를 재구성:
   - k6 트래픽 흘리는 중에 인스턴스 1대 강제 종료
   - ALB가 healthy 인스턴스로만 라우팅 → 서비스 무중단
   - ASG가 자동으로 대체 인스턴스 기동
4. 사이트의 시나리오 4 제목을 변경: "EC2 장애 → 전체 중단" ❌ → **"SPOF 발견과 제거: ALB + ASG로 무중단 검증"** ✅

### 증거 캡처 목록
- [ ] Terraform apply 결과 (추가된 리소스 수)
- [ ] ALB Target Group — 2대 모두 healthy
- [ ] 인스턴스 1대 종료 직후 — 1대 unhealthy 상태
- [ ] **핵심 컷**: 종료 시간대 k6 성공률 그래프 — 트래픽 유지됨 (에러율 0% 또는 순간 스파이크 후 회복)
- [ ] ASG Activity History — 자동으로 새 인스턴스 Launching 기록
- [ ] 몇 분 후 다시 2대 healthy 복귀

---

## Phase 3. 장애 시나리오를 현실형으로 교체 (예상 3~4일)

SG 차단 시나리오는 1개만 남기고(네트워크 장애 대표), 나머지는 아래로 교체.

### 시나리오 1 수정 — "SG 차단" → "커넥션 풀 고갈" (상세 절차)

**개념**: 실무에서 가장 흔한 DB 장애. 커넥션이 꽉 차서 신규 요청이 `ERROR 1040: Too many connections`로 실패.

**절차 (그대로 따라 하면 됨)**:

1. **준비**: RDS 파라미터 그룹에서 member-db의 `max_connections`를 20으로 낮춤 (재현 쉽게)
   - 📸 캡처: 파라미터 그룹 설정 화면
2. **정상 상태 확인**: EC2에서 member API 호출 성공 + `SHOW STATUS LIKE 'Threads_connected';` 결과
   - 📸 캡처: 현재 커넥션 수 (예: 3)
3. **장애 주입**: 스크립트로 커넥션 25개 점유
   ```bash
   # fault-scenarios/01_connection_exhaustion.sh
   for i in $(seq 1 25); do
     mysql -h $MEMBER_DB_HOST -u admin -p$PW \
       -e "SELECT SLEEP(600);" member_db &
   done
   ```
   - 📸 캡처: 스크립트 실행 화면 + `date` 명령으로 주입 시각 기록
4. **장애 재현 확인**:
   - 신규 mysql 접속 시도 → `ERROR 1040 (HY000): Too many connections`
   - k6 돌리는 중이면: member API 5xx, payment/cart API 정상
   - 📸 캡처: ERROR 1040 터미널 / k6 결과 대비 / `SHOW PROCESSLIST` (SLEEP 쿼리 25개)
5. **감지 확인**: CloudWatch `DatabaseConnections` 알람 In alarm 전환 + SNS 메일 수신
   - 📸 캡처: 알람 그래프(임계선 돌파 지점) + 메일 타임스탬프
6. **복구**:
   ```sql
   -- 점유 커넥션 강제 종료
   SELECT CONCAT('KILL ', id, ';') FROM information_schema.processlist
   WHERE command='Sleep' OR info LIKE '%SLEEP%';
   ```
   실행 후 신규 접속 성공 확인, 파라미터 원복
   - 📸 캡처: KILL 실행 → 접속 성공 → 커넥션 수 정상화 그래프
7. **재발 방지 (런북에 기록)**:
   - 앱 커넥션 풀 상한 설정 (SQLAlchemy `pool_size=5, max_overflow=5`)
   - `DatabaseConnections` 알람 임계를 max의 80%로 설정
   - 📸 캡처: 코드에 풀 설정 반영한 커밋

### 시나리오 2 수정 — "SG 차단" → "슬로우 쿼리로 CPU 급등"

1. payment-db에 더미 데이터 100만 건 삽입 (스크립트로)
2. 인덱스 없는 컬럼으로 `LIKE '%검색%'` 풀스캔 쿼리를 반복 실행 → CPU 80%+ 급등
3. 감지: `CPUUtilization` 알람 발화
4. 진단: `SHOW PROCESSLIST`로 범인 쿼리 특정 → `EXPLAIN`으로 풀스캔 확인
5. 복구: 인덱스 추가 → `EXPLAIN` 재실행 (rows 100만 → 수십), CPU 정상화
- 📸 캡처: CPU 그래프 급등→정상, EXPLAIN 전/후 대비(이게 킬러 컷), 쿼리 실행시간 전/후

### 시나리오 3 수정 — "IAM 거부" → "DynamoDB 쓰기 스로틀링"

1. cart 테이블을 On-demand → Provisioned(WCU 1)로 변경
2. 스크립트로 초당 수십 건 PutItem 폭주 → `ProvisionedThroughputExceededException`
3. 감지: `WriteThrottleEvents` 알람 발화
4. 복구: On-demand 복귀(또는 WCU 증설) → 쓰기 정상화
5. 재발 방지: 앱에 exponential backoff 재시도 로직
- 📸 캡처: 스로틀 예외 터미널, ThrottledRequests 그래프, 복구 후 정상 그래프

### 유지할 것
- 기존 SG 차단 시나리오 1개 (네트워크 장애 대표로)
- Multi-AZ Failover 시나리오 (이건 이미 좋음 — 단, Phase 4에서 다운타임 초 단위 실측 추가)

---

## Phase 4. 숫자 실측 — MTTD / MTTR (각 시나리오마다, 추가 0.5일)

### 왜
"RTO 3–10분"이 목표값인지 측정값인지 불명확 → 현업자가 가장 의심하는 부분.

### 할 일
모든 시나리오 실행 시 **타임라인 표**를 만들어 기록:

| 이벤트 | 시각 | 소요 |
|---|---|---|
| 장애 주입 (`date` 명령 캡처) | 14:00:00 | — |
| CloudWatch 알람 In alarm | 14:02:10 | **MTTD 2분 10초** |
| SNS 메일 수신 (메일 헤더 시각) | 14:02:34 | +24초 |
| 복구 조치 시작 | 14:04:00 | — |
| 서비스 정상 확인 (k6 성공률 회복) | 14:06:30 | **MTTR 6분 30초** |

- 📸 캡처: 주입 시 터미널의 `date` 출력, 알람 History 탭(상태 전환 시각), 메일 수신 시각
- 사이트의 "RTO 3–10분"을 → **"실측 MTTD 평균 X분, MTTR 평균 Y분 (5개 시나리오)"**로 교체

---

## Phase 5. 트레이드오프 문서 (0.5~1일)

### 왜
"분리의 장점"만 있고 "분리의 대가"가 없음 → 깊이 부족의 핵심 원인.

### 할 일
`docs/tradeoffs.md` 1페이지 작성. 구성:

1. **크로스 도메인 조회 문제**: "회원 이름 + 결제 내역" 조인 불가 → 내 선택: 앱 레벨에서 2회 조회 후 조합. 대규모라면 CQRS/읽기 전용 뷰 고려.
2. **트랜잭션 정합성**: 주문-결제가 다른 DB → 분산 트랜잭션 불가 → 내 선택: 이 규모에선 앱 레벨 보상 로직(결제 실패 시 주문 롤백). 대규모라면 Saga 패턴.
3. **비용 증가**: RDS 1대 → 2대 + Multi-AZ. Cost Explorer 실측 월 비용 캡처 첨부 → "가용성을 위해 월 $X 추가를 감수한 판단"
4. **운영 복잡도**: 백업/파라미터/알람이 DB 수만큼 증가 → Terraform으로 상쇄

- 📸 캡처: Cost Explorer 월 비용 내역
- 사이트에 "07 · Trade-offs" 섹션 추가 (Learnings 앞에)

---

## Phase 6. CI/CD 파이프라인 (0.5일)

### 할 일
1. GitHub Actions 워크플로: PR 시 `terraform fmt -check` → `validate` → `plan` → `tfsec` 정적 보안 검사
2. tfsec가 실제로 지적한 항목 1개 이상 수정 (예: SG 규칙, 암호화 미설정) → "도구로 발견 → 수정" 스토리

### 증거 캡처 목록
- [ ] Actions 실행 성공 화면 (단계별 초록 체크)
- [ ] tfsec 발견 항목 → 수정 커밋 → 재검사 통과 (before/after)

---

## 사이트 반영 체크리스트 (전부 끝난 뒤)

- [ ] 히어로 숫자 교체: "RTO 3–10분" → "실측 MTTD/MTTR"
- [ ] Architecture 다이어그램에 ALB + ASG 반영
- [ ] 시나리오 4 → "SPOF 발견과 제거" 서사로 재작성
- [ ] 시나리오 1~3 → 현실형 장애로 교체 (각각 타임라인 표 포함)
- [ ] Trade-offs 섹션 신설
- [ ] Evidence에 k6 대비 그래프를 최상단 배치
- [ ] Stack에 k6, GitHub Actions, ALB/ASG 추가

## 총 예상 기간: 집중하면 2주, 여유 있게 3주
