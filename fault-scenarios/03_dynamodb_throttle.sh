#!/bin/bash
# 시나리오 03: DynamoDB 쓰기 스로틀링 (batch-write 25건씩 폭주)
export AWS_PAGER="" AWS_MAX_ATTEMPTS=1
TABLE="ecommerce-portfolio-cart"; REGION="ap-northeast-2"

echo "=== 장애 주입 시작: $(date '+%F %T') ==="

# 1단계: batch-write로 버스트 용량 고속 소진 (60회 x 25건 = 1500건 시도)
for b in $(seq 1 60); do
  ITEMS=$(for i in $(seq 1 25); do
    echo -n "{\"PutRequest\":{\"Item\":{\"user_id\":{\"S\":\"flood-b$b\"},\"product_id\":{\"S\":\"p-$RANDOM-$i\"},\"qty\":{\"N\":\"1\"}}}},"
  done)
  OUT=$(aws dynamodb batch-write-item --region "$REGION" \
    --request-items "{\"$TABLE\":[${ITEMS%,}]}" 2>&1)
  if echo "$OUT" | grep -q ProvisionedThroughputExceededException; then
    echo "[batch$b] THROTTLED - 전체 거부 $(date '+%T')"
  elif echo "$OUT" | grep -q '"PutRequest"'; then
    echo "[batch$b] THROTTLED - 일부 미처리 $(date '+%T')"
  fi
done

# 2단계: 단건 put-item으로 깔끔한 예외 메시지 증거 확보
for i in $(seq 1 10); do
  OUT=$(aws dynamodb put-item --table-name "$TABLE" --region "$REGION" \
    --item "{\"user_id\":{\"S\":\"single\"},\"product_id\":{\"S\":\"s-$i\"},\"qty\":{\"N\":\"1\"}}" 2>&1) \
    || { echo "$OUT" | grep -q ProvisionedThroughputExceededException \
         && echo "[single$i] THROTTLED $(date '+%T')"; }
done

echo "=== 장애 주입 종료: $(date '+%F %T') ==="
