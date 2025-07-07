#!/bin/bash

echo "=== 完全なSAGA動作確認 ==="
echo ""

# 1. カテゴリを作成
echo "1. カテゴリの作成..."
CATEGORY_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createCategory(input: { name: \"SAGA Test Category\" }) { id name } }"
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
      \"query\": \"mutation { createProduct(input: { name: \\\"SAGA Test Product\\\", price: 100.0, categoryId: \\\"$CATEGORY_ID\\\" }) { id name price } }\"
    }" -s)
  
  echo "$PRODUCT_RESPONSE" | jq
  PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | jq -r '.data.createProduct.id')
  
  # 3. 通常の注文作成
  if [ "$PRODUCT_ID" != "null" ] && [ -n "$PRODUCT_ID" ]; then
    echo ""
    echo "3. 通常の注文作成..."
    ORDER_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
      -H "Content-Type: application/json" \
      -d "{
        \"query\": \"mutation { createOrder(input: { userId: \\\"user-123\\\", items: [{productId: \\\"$PRODUCT_ID\\\", quantity: 2}] }) { id status totalAmount } }\"
      }" -s)
    
    echo "$ORDER_RESPONSE" | jq
    ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.data.createOrder.id')
    
    # 4. SAGA経由の注文作成
    echo ""
    echo "4. SAGA経由の注文作成..."
    SAGA_ORDER_ID="order-saga-$(date +%s)"
    SAGA_RESPONSE=$(curl -X POST http://localhost:4000/graphql \
      -H "Content-Type: application/json" \
      -d "{
        \"query\": \"mutation { startOrderSaga(input: { orderId: \\\"$SAGA_ORDER_ID\\\", userId: \\\"user-123\\\", items: [{productId: \\\"$PRODUCT_ID\\\", quantity: 1}], totalAmount: 100.0 }) { sagaId success message startedAt } }\"
      }" -s)
    
    echo "$SAGA_RESPONSE" | jq
    
    # 5. SAGAの状態確認
    if [ "$ORDER_ID" != "null" ] && [ -n "$ORDER_ID" ]; then
      echo ""
      echo "5. SAGAの状態確認..."
      sleep 2
      
      SAGA_STATE=$(curl -X POST http://localhost:4000/graphql \
        -H "Content-Type: application/json" \
        -d "{
          \"query\": \"query { sagaState(orderId: \\\"$ORDER_ID\\\") { state status startedAt currentStep } }\"
        }" -s)
      
      echo "$SAGA_STATE" | jq
    fi
  fi
fi

# 6. ログ確認
echo ""
echo "6. SAGAコーディネーターのログ..."
docker compose logs command-service --tail 100 | grep -i "saga" | tail -10

echo ""
echo "=== 動作確認完了 ==="