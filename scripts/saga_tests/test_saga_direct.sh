#!/bin/bash

echo "=== SAGA直接動作確認 ==="
echo ""

# 1. 商品を作成
echo "1. 商品の作成..."
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createCategory(input: { name: \"Test Category\", description: \"Test\" }) { id name } }"
  }' -s | jq -r '.data.createCategory.id' > /tmp/category_id.txt

CATEGORY_ID=$(cat /tmp/category_id.txt)
echo "   カテゴリID: $CATEGORY_ID"

curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"mutation { createProduct(input: { name: \\\"Test Product\\\", description: \\\"Test\\\", price: 100.0, stock: 10, categoryId: \\\"$CATEGORY_ID\\\" }) { id name } }\"
  }" -s | jq -r '.data.createProduct.id' > /tmp/product_id.txt

PRODUCT_ID=$(cat /tmp/product_id.txt)
echo "   商品ID: $PRODUCT_ID"

# 2. SAGAのgRPCサーバーが動作しているか確認
echo ""
echo "2. SAGAコマンドサーバーの確認..."
grpcurl -plaintext localhost:50051 list 2>/dev/null | grep -i saga || echo "   SAGAサービスが見つかりません"

# 3. Orderの作成を試す
echo ""
echo "3. 注文の作成..."
ORDER_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d "{
    \"query\": \"mutation { createOrder(input: { userId: \\\"user-123\\\", items: [{productId: \\\"$PRODUCT_ID\\\", quantity: 2, price: 100.0}] }) { id status totalAmount } }\"
  }" -s)

echo "   レスポンス:"
echo "$ORDER_RESPONSE" | jq

# 4. SAGAの状態を確認（もし実装されていれば）
ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.data.createOrder.id' 2>/dev/null)
if [ "$ORDER_ID" != "null" ] && [ -n "$ORDER_ID" ]; then
  echo ""
  echo "4. SAGAの状態確認..."
  curl -X POST http://localhost:4000/graphql \
    -H "Content-Type: application/json" \
    -d "{
      \"query\": \"query { sagaState(orderId: \\\"$ORDER_ID\\\") { sagaId status startedAt } }\"
    }" -s | jq || echo "   SAGA状態エンドポイントは未実装です"
fi

echo ""
echo "=== 動作確認完了 ==="