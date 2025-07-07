#!/bin/bash

echo "=== SAGA動作確認（修正版） ==="
echo ""

# 1. カテゴリを作成
echo "1. カテゴリの作成..."
CATEGORY_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createCategory(input: { name: \"Test Category for SAGA\", description: \"SAGA Test\" }) { id name } }"
  }' -s)

CATEGORY_ID=$(echo "$CATEGORY_RESPONSE" | jq -r '.data.createCategory.id')
echo "   カテゴリID: $CATEGORY_ID"

# 2. 商品を作成
echo ""
echo "2. 商品の作成..."
PRODUCT_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"mutation { createProduct(input: { name: \\\"Test Product for SAGA\\\", description: \\\"SAGA Test Product\\\", price: 100.0, stock: 10, categoryId: \\\"$CATEGORY_ID\\\" }) { id name price stock } }\"
  }" -s)

echo "$PRODUCT_RESPONSE" | jq

PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | jq -r '.data.createProduct.id')
echo "   商品ID: $PRODUCT_ID"

# 3. 注文の作成（SAGAが起動するはず）
echo ""
echo "3. 注文の作成（SAGAの起動）..."
ORDER_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"mutation { createOrder(input: { userId: \\\"user-123\\\", items: [{productId: \\\"$PRODUCT_ID\\\", quantity: 2}] }) { id status totalAmount createdAt } }\"
  }" -s)

echo "   レスポンス:"
echo "$ORDER_RESPONSE" | jq

ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.data.createOrder.id' 2>/dev/null)

# 4. 注文の詳細を確認
if [ "$ORDER_ID" != "null" ] && [ -n "$ORDER_ID" ]; then
  echo ""
  echo "4. 注文の詳細確認..."
  sleep 2  # SAGAの処理を待つ
  
  ORDER_DETAIL=$(curl -X POST http://localhost:4000/graphql \
    -H "Content-Type: application/json" \
    -d "{
      \"query\": \"query { order(id: \\\"$ORDER_ID\\\") { id status totalAmount items { productId productName quantity price subtotal } createdAt } }\"
    }" -s)
  
  echo "$ORDER_DETAIL" | jq
  
  # 5. SAGAの状態を確認（実装されていれば）
  echo ""
  echo "5. SAGAの状態確認..."
  SAGA_STATE=$(curl -X POST http://localhost:4000/graphql \
    -H "Content-Type: application/json" \
    -d "{
      \"query\": \"query { sagaState(orderId: \\\"$ORDER_ID\\\") { state status startedAt currentStep } }\"
    }" -s)
  
  echo "$SAGA_STATE" | jq
fi

# 6. コマンドサービスのログを確認
echo ""
echo "6. SAGAのログを確認..."
docker compose logs command-service --tail 50 | grep -i "saga\|order" | tail -10

echo ""
echo "=== 動作確認完了 ==="