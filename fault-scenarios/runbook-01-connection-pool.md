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
- 앱 커넥션 풀 상한 설정 (예: pool_size + max_overflow로 DB max_connections 이내 제한)
- `DatabaseConnections` 알람 임계를 `max_connections`의 80% 수준으로 유지 (조기 감지)
  - 현재 알람 임계: `> 50` (`terraform/monitoring.tf`)
  - `max_connections` 실측값 **미확인**. RDS MySQL 기본값은 `{DBInstanceClassMemory/12582880}` 공식으로 산출되며, 파라미터 그룹을 리포에 포함하지 않아 구체 수치는 확정하지 않았다. 재구축 시 `SHOW VARIABLES LIKE 'max_connections';` 로 확인 후 기입한다.

## 근거
- 스크린샷: `docs/screenshots/fault-01-connection-pool/01_injection_503.png` ~ `04_alarm_in_alarm.png` (4장)
- 수치 근거: CloudWatch 알람 히스토리 + `get-metric-statistics` (0→58→0 추이)