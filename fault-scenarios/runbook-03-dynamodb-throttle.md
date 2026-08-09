# Runbook 03: DynamoDB 쓰기 스로틀링 (cart 테이블)

## 증상
- cart 쓰기 요청에서 `ProvisionedThroughputExceededException` 발생
- member / payment API는 정상 (도메인 분리로 장애 격리)

## 실측 타임라인 (2026-08-01 KST)
| 이벤트 | 시각 | 소요 |
|---|---|---|
| 준비: On-demand → Provisioned WCU 1 변경 | 14:57:37 | — |
| 1차 주입 (버스트 용량에 흡수되어 무효) | 15:05:53~15:08:20 | — |
| 2차 주입 → THROTTLED 발생 | 15:09:06 → 15:13:10 | **감지 실패** |
| 원인: 알람이 잘못된 메트릭 감시 중 발견 | — | — |
| Terraform으로 알람 수정 (`WriteThrottleEvents >= 1`) | — | — |
| 3차 주입(확정) 시작 → 첫 THROTTLED | 15:37:41 → 15:37:55 | — |
| 알람 In alarm | 15:39:51 | **MTTD 2분 10초** |
| 복구 apply (On-demand 복귀) → 쓰기 정상화 | 15:46:20 → 15:46:22 | **MTTR 8분 41초** (주입 기준) |

## 핵심 교훈: 장애는 났는데 모니터링이 침묵했다
기존 알람은 `ConsumedWriteCapacityUnits > 500`을 감시 → 실제 스로틀링이 발생해도 감지 불가.
`WriteThrottleEvents >= 1`로 교체 후 재주입으로 감지 검증까지 완료.
**알람은 "만들어둔 것"이 아니라 "실제 장애로 검증한 것"만 신뢰할 수 있다.**

## 진단 절차
1. 앱/스크립트 에러에서 `ProvisionedThroughputExceededException` 확인
2. CloudWatch → `WriteThrottleEvents` 메트릭에서 스로틀 발생 확인
3. `aws dynamodb describe-table`로 billing mode / WCU 확인

## 복구 절차 (IaC 기반)
1. `dynamodb_cart.tf`의 `billing_mode`를 `PAY_PER_REQUEST`로 되돌림
2. `terraform apply` → 쓰기 정상화 확인
3. 알람 OK 전환 확인

## 재발 방지
- 스로틀링 알람은 `WriteThrottleEvents >= 1` 기준 유지 (Terraform 관리)
- 앱 쓰기 로직에 exponential backoff 재시도 적용 검토
- 용량 변경은 콘솔/CLI 수동 조작 대신 Terraform으로만 수행 (state 불일치 방지)

## 근거
- 스크린샷: `docs/screenshots/fault-03-dynamodb/01_wcu1_setup.png` ~ `05-2_alarm_inalarm_history.png` (8장)
- 복구 증거: 터미널 텍스트 (apply 완료 15:46:20, 쓰기 성공 15:46:22)