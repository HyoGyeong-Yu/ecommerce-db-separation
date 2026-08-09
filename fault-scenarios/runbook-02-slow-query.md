# Runbook 02: 슬로우 쿼리 폭주로 CPU 급등 (member-db)

## 증상
- member-db `CPUUtilization` 100% 지속
- 커넥션 수는 정상 범위 → 외부 트래픽이 아닌 내부 쿼리가 원인이라는 신호

## 실측 타임라인 (2026-08-01 KST)
| 이벤트 | 시각 | 소요 |
|---|---|---|
| 슬로우 쿼리(무인덱스 대량 조인) 시작 | ~13:18 | — |
| 알람 `ecommerce-portfolio-member-db-cpu-high` In alarm | 13:25:02 | **MTTD 약 7분** |
| 잔여 세션 정리 누락 → 장기 방치 | 13:25~15:53 | — |
| 원인 발견 → KILL 스크립트 실행 → 알람 OK | 15:55:10 | **KILL 후 정상화 약 2분** |

**MTTR 표기 — 두 기준 병기**

| 기준 | 값 | 설명 |
|---|---|---|
| 주입 → 알람 OK (다른 시나리오와 동일 기준) | **약 2시간 30분** | 잔여 세션 방치로 장애가 지속된 실제 소요 |
| 원인 인지 → 정상화 (조치 기준) | **약 2분** | 원인을 안 뒤의 순수 복구 시간 |

두 값의 차이가 곧 이 시나리오의 교훈이다. 유리한 쪽만 쓰지 않고 둘 다 남긴다.

## 진단 절차
1. CloudWatch에서 CPU 100% + `DatabaseConnections` 정상 조합 확인 → 내부 쿼리 의심
2. `SHOW FULL PROCESSLIST` → Time이 수천 초인 장기 실행 쿼리 다수 발견
3. `EXPLAIN <해당 쿼리>` → 풀스캔/카티전 조인 여부 확인

## 복구 절차
1. 장기 실행 세션 일괄 종료:
```sql
   SELECT CONCAT('KILL ', id, ';') FROM information_schema.processlist
   WHERE user='admin' AND time > 60;
   -- 출력된 KILL 문 실행
```
2. CPU 하강 및 알람 OK 전환 확인
3. 근본 해결: 조회 컬럼에 인덱스 추가 → `EXPLAIN` 재실행으로 스캔 행 수 감소 확인

## 사후 회고 (실제 발생한 운영 실수)
장애 증거 수집 후 주입 세션을 정리하지 않아 CPU 100%가 약 2시간 반 방치됨.
별도 작업 중 지속 알람을 조사하다 발견 → KILL로 복구.
**재발 방지: 시나리오 종료 체크리스트에 "PROCESSLIST 확인 → 잔여 세션 정리" 단계 추가.**

## 근거
- CloudWatch 알람 히스토리 (In alarm 13:25:02 → OK 15:55:10)
- 스크린샷: `docs/screenshots/fault-02-slow-query/01_cpu_spike.png`, `02_explain_diagnosis.png`, `03_alarm_in_alarm.png` (3장)