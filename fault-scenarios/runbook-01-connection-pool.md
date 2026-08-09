# Runbook 01: RDS 커넥션 슬롯 고갈 (member-db)

> **용어 정정:** 이 앱(`app/main.py`)은 요청마다 `pymysql.connect()`로 새 연결을 만들며 애플리케이션 레벨 커넥션 풀이 없다. 따라서 이 장애는 "커넥션 풀 고갈"이 아니라 **RDS 인스턴스의 커넥션 슬롯(`max_connections`) 고갈**이다. 초기 문서는 풀 고갈로 표기했으나, 코드와 대조해 정정했다.

## 증상
- member API(`GET /members`)만 503 반환 — payment / cart API는 정상 (도메인 분리로 장애 격리)
- CloudWatch `DatabaseConnections` 급등 (0 → 58)

## 실측 타임라인 (2026-08-01 KST)
| 이벤트 | 시각 | 소요 |
|---|---|---|
| 장애 주입 — SLEEP 쿼리로 커넥션 58개 점유 | 12:55 | — |
| 알람 `member-db-high-connections` In alarm | 12:56:19 | **MTTD 1분 20초** |
| 커넥션 정상화 (58 → 0) | 13:07 | — |
| 알람 OK 복귀 | 13:08:19 | **MTTR 약 12분** (주입 기준) |

## 진단 절차
1. CloudWatch → `DatabaseConnections` 그래프에서 급등 시점 확인
2. EC2에서 세션 목록으로 원인 쿼리 특정:
```sql
   SHOW FULL PROCESSLIST;
   -- Command='Sleep' 또는 SLEEP() 쿼리 다수 = 커넥션 점유 원인
```
3. 다른 도메인 API 호출로 장애 범위 확인 (payment/cart 정상 = member-db 국소 장애)

## 복구 절차
1. 점유 세션 강제 종료:
```sql
   SELECT CONCAT('KILL ', id, ';') FROM information_schema.processlist
   WHERE command='Sleep' OR info LIKE '%SLEEP%';
   -- 출력된 KILL 문 실행
```
2. 신규 접속 성공 확인 → member API 200 복귀 확인
3. 알람 OK 전환 확인

## 재발 방지
- 앱 커넥션 풀 도입 — 요청마다 새 연결을 만드는 현재 구조를 풀 재사용으로 전환하고,
  풀 상한을 DB 슬롯 여유 범위 내로 제한 (`DBUtils.PooledDB`, `maxconnections=10`)
  - ASG 최대 4대 x 10 = 40 < `max_connections` 63 → 앱이 슬롯을 전부 잠식하지 못하도록 상한 보장
  - **상태: 설계 완료 / 실행 검증 미완료** (AWS 리소스 삭제 후 결정된 개선안)
- `DatabaseConnections` 알람 임계를 `max_connections`의 80% 수준으로 유지 (조기 감지)

### 커넥션 한계 산정 근거

| 항목 | 값 | 근거 |
|---|---|---|
| DB 인스턴스 클래스 | `db.t3.micro` (MySQL 8.0, 기본 파라미터 그룹) | `terraform/rds_member.tf` |
| `max_connections` 산식 | `{DBInstanceClassMemory/12582880}` | `default.mysql8.0` 파라미터 그룹 |
| **`max_connections` 값** | **63** | 동일 스펙(db.t3.micro / MySQL 8.0) 기준값. `DBInstanceClassMemory`는 OS·RDS 예약 메모리를 제외한 값이라 단순 계산(1GiB / 12,582,880 = 약 85)보다 낮게 산출됨 |
| 알람 임계 | 50 = **상한의 약 79%** | `terraform/monitoring.tf` |
| 장애 시 실측 피크 | 58 (그래프 상 59) | CloudWatch `DatabaseConnections` |

임계 50은 상한 63의 약 80% 지점이며, 실측 피크 58은 상한의 **92%** 로
슬롯이 사실상 소진 직전까지 갔음을 의미한다.
알람이 In alarm으로 전환된 시점(12:56:19)은 아직 신규 접속 여지가 남아 있던 구간으로,
임계 설정이 조기 감지 목적에 부합했음을 보여준다.

> 본 시나리오의 주입 스크립트는 `SHOW STATUS LIKE 'Threads_connected'`(현재 접속 수)만 조회했고
> `SHOW VARIABLES LIKE 'max_connections'`(상한)은 조회하지 않았다. 이 누락을 문서 감사 과정에서
> 발견해 재현 스크립트에 상한 조회 단계를 추가했다. 재구축 시 이 출력으로 위 값을 확정 기록한다.
> 참고: https://repost.aws/questions/QUb0eVsMLySaWLvFj2SKfUFg

## 근거
- 스크린샷: `docs/screenshots/fault-01-connection-pool/01_injection_503.png` ~ `04_alarm_in_alarm.png` (4장)
- 수치 근거: CloudWatch 알람 히스토리 + `get-metric-statistics` (0→58→0 추이)