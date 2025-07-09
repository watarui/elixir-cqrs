#!/bin/bash

# API テスト用スクリプト

echo "=== CQRS/ES/SAGA マイクロサービス API テスト ==="
echo ""

# GraphQL エンドポイント
GRAPHQL_URL="http://localhost:4000/api/graphql"

echo "1. カテゴリーの作成"
curl -X POST $GRAPHQL_URL \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createCategory(input: { name: \"電化製品\" }) { id name createdAt } }"
  }' | jq .

echo -e "\n2. 商品の作成"
curl -X POST $GRAPHQL_URL \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createProduct(input: { name: \"ノートパソコン\", price: 120000, categoryId: \"1\" }) { id name price { amount currency } category { name } } }"
  }' | jq .

echo -e "\n3. 全カテゴリーの取得"
curl -X POST $GRAPHQL_URL \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { categories { id name products { id name price { amount } } } }"
  }' | jq .

echo -e "\n4. 商品の検索"
curl -X POST $GRAPHQL_URL \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { products(filter: { categoryId: \"1\" }) { id name price { amount currency } category { name } } }"
  }' | jq .

echo -e "\n5. 注文の作成（SAGAパターンのテスト）"
curl -X POST $GRAPHQL_URL \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createOrder(input: { userId: \"user-123\", items: [{ productId: \"1\", quantity: 2, unitPrice: 120000 }] }) { orderId message } }"
  }' | jq .

echo -e "\n=== Jaeger UI でトレースを確認 ==="
echo "http://localhost:16686 にアクセスしてトレースを確認できます"

echo -e "\n=== Prometheus でメトリクスを確認 ==="
echo "http://localhost:9090 にアクセスしてメトリクスを確認できます"

echo -e "\n=== Grafana でダッシュボードを確認 ==="
echo "http://localhost:3000 にアクセスしてダッシュボードを確認できます（admin/admin）"