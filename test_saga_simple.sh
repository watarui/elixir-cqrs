#!/bin/bash

echo "=== SAGA動作確認（シンプル版） ==="
echo ""

# 1. カテゴリを作成
echo "1. カテゴリの作成..."
CATEGORY_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createCategory(input: { name: \"Test Category\" }) { id name } }"
  }' -s)

echo "$CATEGORY_RESPONSE" | jq
CATEGORY_ID=$(echo "$CATEGORY_RESPONSE" | jq -r '.data.createCategory.id')

# 2. 商品を作成
if [ "$CATEGORY_ID" != "null" ] && [ -n "$CATEGORY_ID" ]; then
  echo ""
  echo "2. 商品の作成..."
  PRODUCT_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
    -H "Content-Type: application/json" \
    -d "{
      \"query\": \"mutation { createProduct(input: { name: \\\"Test Product\\\", price: 100.0, categoryId: \\\"$CATEGORY_ID\\\" }) { id name price } }\"
    }" -s)
  
  echo "$PRODUCT_RESPONSE" | jq
  PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | jq -r '.data.createProduct.id')
  
  # 3. 注文の作成
  if [ "$PRODUCT_ID" != "null" ] && [ -n "$PRODUCT_ID" ]; then
    echo ""
    echo "3. 注文の作成（SAGAの起動）..."
    ORDER_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
      -H "Content-Type: application/json" \
      -d "{
        \"query\": \"mutation { createOrder(input: { userId: \\\"user-123\\\", items: [{productId: \\\"$PRODUCT_ID\\\", quantity: 2}] }) { id status totalAmount } }\"
      }" -s)
    
    echo "$ORDER_RESPONSE" | jq
    
    # 4. SAGACoordinatorのログを確認
    echo ""
    echo "4. SAGACoordinatorのログ確認..."
    docker compose logs command-service --tail 100 | grep -E "SagaCoordinator|saga_coordinator|SAGA" | tail -20
  fi
fi

echo ""
echo "=== 動作確認完了 ==="#