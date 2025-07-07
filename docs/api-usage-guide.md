# API 利用ガイド

## 概要

このプロジェクトは、GraphQL APIをメインインターフェースとして提供しています。

## API エンドポイント

### GraphQL API

- **エンドポイント**: `http://localhost:4000/graphql`
- **Playground**: `http://localhost:4000/graphiql` (開発環境のみ)


## GraphQL Playground の使い方

1. ブラウザで `http://localhost:4000/graphiql` を開く
2. 左側のエディタにクエリを入力
3. "Play" ボタンをクリックして実行
4. 右側に結果が表示される

### Playground の機能

- **自動補完**: Ctrl+Space で利用可能
- **ドキュメント探索**: 右側の "Docs" タブ
- **履歴**: 左側の "History" タブ
- **変数エディタ**: 下部の "Query Variables" セクション

## クイックスタート

### 1. カテゴリの作成

**GraphQL:**
```graphql
mutation {
  createCategory(input: {name: "Electronics"}) {
    id
    name
  }
}
```

### 2. 商品の作成

カテゴリIDを取得してから実行：

**GraphQL:**
```graphql
mutation {
  createProduct(input: {
    name: "iPhone 15"
    price: 999.99
    categoryId: "YOUR_CATEGORY_ID"
  }) {
    id
    name
    price
  }
}
```

### 3. 商品一覧の取得（カテゴリ情報付き）

**GraphQL:**
```graphql
query {
  products {
    id
    name
    price
    category {
      id
      name
    }
  }
}
```

## 高度な使用例

### バッチクエリ

複数の操作を一度に実行：

```graphql
query BatchOperation {
  electronics: categoryByName(name: "Electronics") {
    id
    products {
      name
      price
    }
  }
  
  expensiveProducts: productsByPriceRange(minPrice: 500, maxPrice: 2000) {
    id
    name
    price
  }
  
  stats: productStatistics {
    totalCount
    averagePrice
  }
}
```

### フラグメントの使用

共通フィールドの再利用：

```graphql
fragment ProductDetails on Product {
  id
  name
  price
  createdAt
  updatedAt
}

query {
  product(id: "123") {
    ...ProductDetails
    category {
      name
    }
  }
  
  products {
    ...ProductDetails
  }
}
```

### 変数の使用

動的な値の注入：

```graphql
query GetProduct($productId: ID!) {
  product(id: $productId) {
    id
    name
    price
  }
}
```

変数:
```json
{
  "productId": "123e4567-e89b-12d3-a456-426614174000"
}
```

## エラーハンドリング

### GraphQL エラー形式

```json
{
  "data": null,
  "errors": [
    {
      "message": "Product not found",
      "path": ["product"],
      "extensions": {
        "code": "NOT_FOUND"
      }
    }
  ]
}
```

## パフォーマンス最適化

### 1. 必要なフィールドのみ取得

**悪い例:**
```graphql
query {
  products {
    id
    name
    price
    categoryId
    category {
      id
      name
      createdAt
      updatedAt
      products {
        # N+1問題を引き起こす可能性
        id
        name
      }
    }
    createdAt
    updatedAt
  }
}
```

**良い例:**
```graphql
query {
  products {
    id
    name
    price
    category {
      name
    }
  }
}
```

### 2. ページネーションの使用

大量のデータを扱う場合：

```graphql
query {
  productsPaginated(page: 1, perPage: 20) {
    id
    name
    price
  }
}
```

### 3. 検索の最適化

特定の条件でフィルタリング：

```graphql
query {
  productsByPriceRange(minPrice: 100, maxPrice: 500) {
    id
    name
    price
  }
}
```

## 開発者向けツール

### 1. GraphQL スキーマの確認

```graphql
query {
  __schema {
    types {
      name
      kind
      description
    }
  }
}
```

### 2. 特定の型の詳細

```graphql
query {
  __type(name: "Product") {
    name
    fields {
      name
      type {
        name
        kind
      }
      description
    }
  }
}
```

### 3. cURL での実行

変数を含むクエリ：

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query GetProduct($id: ID!) { product(id: $id) { name price } }",
    "variables": {
      "id": "123e4567-e89b-12d3-a456-426614174000"
    }
  }'
```

## SDK/クライアントライブラリの例

### JavaScript (Apollo Client)

```javascript
import { ApolloClient, InMemoryCache, gql } from '@apollo/client';

const client = new ApolloClient({
  uri: 'http://localhost:4000/graphql',
  cache: new InMemoryCache()
});

// クエリの実行
const GET_PRODUCTS = gql`
  query GetProducts {
    products {
      id
      name
      price
      category {
        name
      }
    }
  }
`;

client.query({ query: GET_PRODUCTS })
  .then(result => console.log(result.data));

// ミューテーションの実行
const CREATE_PRODUCT = gql`
  mutation CreateProduct($input: ProductInput!) {
    createProduct(input: $input) {
      id
      name
    }
  }
`;

client.mutate({
  mutation: CREATE_PRODUCT,
  variables: {
    input: {
      name: "New Product",
      price: 99.99,
      categoryId: "category-id"
    }
  }
});
```

### Python (requests)

```python
import requests
import json

url = "http://localhost:4000/graphql"

# クエリの実行
query = """
query {
  products {
    id
    name
    price
  }
}
"""

response = requests.post(url, json={"query": query})
data = response.json()
print(data)

# ミューテーションの実行
mutation = """
mutation CreateProduct($input: ProductInput!) {
  createProduct(input: $input) {
    id
    name
  }
}
"""

variables = {
  "input": {
    "name": "Python Product",
    "price": 49.99,
    "categoryId": "category-id"
  }
}

response = requests.post(url, json={
  "query": mutation,
  "variables": variables
})
```

## 監視とデバッグ

### メトリクスの確認

```bash
curl http://localhost:4000/metrics
```

### ヘルスチェック

```bash
curl http://localhost:4000/health
```

### トレーシング

Jaeger UIで分散トレースを確認：
- http://localhost:16686

## ベストプラクティス

1. **クエリの深さを制限する**: 過度にネストしたクエリは避ける
2. **バッチング**: 関連するデータは一度のクエリで取得
3. **キャッシング**: クライアント側でキャッシュを活用
4. **エラーハンドリング**: すべてのエラーケースを適切に処理
5. **タイムアウト設定**: 長時間実行されるクエリにはタイムアウトを設定

## トラブルシューティング

### "Service temporarily unavailable" エラー

- バックエンドサービスが起動しているか確認
- `docker compose ps` でサービスの状態を確認
- ログを確認: `docker compose logs -f`

### "Product not found" エラー

- IDが正しいか確認
- 商品が実際に存在するか確認
- データベースの状態を確認

### 接続エラー

- ポート4000が使用可能か確認
- ファイアウォール設定を確認
- ネットワーク接続を確認