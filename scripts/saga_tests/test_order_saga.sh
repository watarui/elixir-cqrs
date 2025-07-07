#!/bin/bash

# OrderSagaの動作確認スクリプト

echo "=== Order SAGA Test ==="
echo

# 1. 商品一覧を確認
echo "1. 商品一覧を確認"
curl -s -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "query { products { id name price categoryId } }"}' | jq '.data.products[0:3]'

echo
echo "2. OrderSagaを開始"

# GraphQLクエリを1行で作成
QUERY='mutation { startOrderSaga(input: { orderId: "order-'$(date +%s)'", userId: "user-123", items: [{productId: "1", quantity: 1}, {productId: "3", quantity: 2}], totalAmount: 306000.0 }) { sagaId success message startedAt } }'

# リクエストを送信
RESPONSE=$(curl -s -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"$QUERY\"}")

echo "$RESPONSE" | jq

# SAGAの結果を確認
if echo "$RESPONSE" | jq -e '.data.startOrderSaga.success == true' > /dev/null 2>&1; then
  echo
  echo "✅ OrderSagaが正常に開始されました"
  
  SAGA_ID=$(echo "$RESPONSE" | jq -r '.data.startOrderSaga.sagaId')
  echo "SAGA ID: $SAGA_ID"
else
  echo
  echo "❌ OrderSagaの開始に失敗しました"
  echo "$RESPONSE" | jq '.errors'
fi