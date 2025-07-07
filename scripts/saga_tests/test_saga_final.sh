#!/bin/bash

echo "=== SAGA Final Test ==="
echo

# GraphQL経由でSAGA mutationを直接実行
echo "1. startOrderSaga mutation を実行"

# JSONを作成
JSON_DATA=$(cat <<EOF
{
  "query": "mutation { startOrderSaga(input: { orderId: \\"order-final-test\\", userId: \\"user-123\\", items: [{productId: \\"1\\", quantity: 1}], totalAmount: 299000.0 }) { sagaId success message startedAt } }"
}
EOF
)

# リクエスト送信
echo "リクエスト送信中..."
RESPONSE=$(curl -s -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA")

echo "レスポンス:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

echo
echo "=== 完了 ==="