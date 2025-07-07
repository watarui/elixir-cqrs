# GraphQL API ドキュメント

## 概要

このプロジェクトのGraphQL APIは、CQRSパターンに基づいて設計されています。すべてのGraphQL操作は内部でコマンドまたはクエリに変換され、適切なサービスにルーティングされます。

## エンドポイント

- **GraphQL API**: `http://localhost:4000/graphql`
- **GraphQL Playground**: `http://localhost:4000/graphiql` (開発環境のみ)

## 認証

現在のバージョンでは認証は実装されていません。すべてのエンドポイントは公開されています。

## スキーマ

### 型定義

#### Product (商品)

```graphql
type Product {
  id: ID!
  name: String!
  price: Float!
  categoryId: ID
  category: Category
  createdAt: DateTime
  updatedAt: DateTime
}
```

#### Category (カテゴリ)

```graphql
type Category {
  id: ID!
  name: String!
  products: [Product!]!
  createdAt: DateTime
  updatedAt: DateTime
}
```

#### ProductStatistics (商品統計)

```graphql
type ProductStatistics {
  totalCount: Int!
  hasProducts: Boolean!
  averagePrice: Float!
  totalValue: Float!
  productsWithTimestamps: Int!
}
```

### クエリ

#### 商品関連

##### 単一商品取得

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    price
    category {
      id
      name
    }
    createdAt
    updatedAt
  }
}
```

##### 商品一覧取得

```graphql
query ListProducts {
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

##### 商品名検索

```graphql
query GetProductByName($name: String!) {
  productByName(name: $name) {
    id
    name
    price
    categoryId
  }
}
```

##### 商品検索

```graphql
query SearchProducts($searchTerm: String!) {
  searchProducts(searchTerm: $searchTerm) {
    id
    name
    price
    category {
      name
    }
  }
}
```

##### ページネーション付き商品一覧

```graphql
query ListProductsPaginated($page: Int!, $perPage: Int!) {
  productsPaginated(page: $page, perPage: $perPage) {
    id
    name
    price
  }
}
```

##### カテゴリ別商品一覧

```graphql
query GetProductsByCategory($categoryId: ID!) {
  productsByCategory(categoryId: $categoryId) {
    id
    name
    price
  }
}
```

##### 価格範囲検索

```graphql
query GetProductsByPriceRange($minPrice: Float!, $maxPrice: Float!) {
  productsByPriceRange(minPrice: $minPrice, maxPrice: $maxPrice) {
    id
    name
    price
  }
}
```

##### 商品統計

```graphql
query GetProductStatistics {
  productStatistics {
    totalCount
    hasProducts
    averagePrice
    totalValue
    productsWithTimestamps
  }
}
```

##### 商品存在確認

```graphql
query CheckProductExists($id: ID!) {
  productExists(id: $id)
}
```

#### カテゴリ関連

##### 単一カテゴリ取得

```graphql
query GetCategory($id: ID!) {
  category(id: $id) {
    id
    name
    products {
      id
      name
      price
    }
    createdAt
    updatedAt
  }
}
```

##### カテゴリ一覧取得

```graphql
query ListCategories {
  categories {
    id
    name
    products {
      id
      name
    }
  }
}
```

##### カテゴリ名検索

```graphql
query GetCategoryByName($name: String!) {
  categoryByName(name: $name) {
    id
    name
  }
}
```

##### カテゴリ存在確認

```graphql
query CheckCategoryExists($id: ID!) {
  categoryExists(id: $id)
}
```

### ミューテーション

#### 商品関連

##### 商品作成

```graphql
mutation CreateProduct($input: ProductInput!) {
  createProduct(input: $input) {
    id
    name
    price
    categoryId
    createdAt
  }
}
```

入力型：
```graphql
input ProductInput {
  name: String!
  price: Float!
  categoryId: ID!
}
```

例：
```json
{
  "input": {
    "name": "MacBook Pro",
    "price": 2999.99,
    "categoryId": "123e4567-e89b-12d3-a456-426614174000"
  }
}
```

##### 商品更新

```graphql
mutation UpdateProduct($input: UpdateProductInput!) {
  updateProduct(input: $input) {
    id
    name
    price
    categoryId
    updatedAt
  }
}
```

入力型：
```graphql
input UpdateProductInput {
  id: ID!
  name: String
  price: Float
  categoryId: ID
}
```

例：
```json
{
  "input": {
    "id": "123e4567-e89b-12d3-a456-426614174001",
    "name": "MacBook Pro M3",
    "price": 3499.99
  }
}
```

##### 商品削除

```graphql
mutation DeleteProduct($id: ID!) {
  deleteProduct(id: $id)
}
```

#### カテゴリ関連

##### カテゴリ作成

```graphql
mutation CreateCategory($input: CategoryInput!) {
  createCategory(input: $input) {
    id
    name
    createdAt
  }
}
```

入力型：
```graphql
input CategoryInput {
  name: String!
}
```

##### カテゴリ更新

```graphql
mutation UpdateCategory($input: UpdateCategoryInput!) {
  updateCategory(input: $input) {
    id
    name
    updatedAt
  }
}
```

入力型：
```graphql
input UpdateCategoryInput {
  id: ID!
  name: String!
}
```

##### カテゴリ削除

```graphql
mutation DeleteCategory($id: ID!) {
  deleteCategory(id: $id)
}
```

## エラーハンドリング

GraphQL APIはすべてのエラーを標準のGraphQLエラー形式で返します。

### エラーレスポンス形式

```json
{
  "data": null,
  "errors": [
    {
      "message": "エラーメッセージ",
      "path": ["operation", "field"],
      "locations": [{"line": 2, "column": 3}]
    }
  ]
}
```

### 一般的なエラー

#### 404 Not Found
```json
{
  "errors": [
    {
      "message": "Product not found"
    }
  ]
}
```

#### 400 Bad Request
```json
{
  "errors": [
    {
      "message": "Invalid price: must be greater than 0"
    }
  ]
}
```

#### 503 Service Unavailable
```json
{
  "errors": [
    {
      "message": "Service temporarily unavailable"
    }
  ]
}
```

## レート制限

現在のバージョンではレート制限は実装されていません。

## 最適化機能

### バッチング

GraphQL Playgroundで複数のクエリを同時に送信できます：

```graphql
query BatchQuery {
  product1: product(id: "id1") {
    id
    name
  }
  product2: product(id: "id2") {
    id
    name
  }
}
```

### N+1問題の解決

カテゴリ情報の取得にはBatchCacheが実装されており、同一リクエスト内での重複したデータベースアクセスを防いでいます。

## 使用例

### cURLでの実行例

#### カテゴリ作成

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation CreateCategory($input: CategoryInput!) { createCategory(input: $input) { id name } }",
    "variables": {
      "input": {
        "name": "Electronics"
      }
    }
  }'
```

#### 商品作成

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation CreateProduct($input: ProductInput!) { createProduct(input: $input) { id name price } }",
    "variables": {
      "input": {
        "name": "iPhone 15",
        "price": 999.99,
        "categoryId": "your-category-id"
      }
    }
  }'
```

#### 商品一覧取得（カテゴリ情報付き）

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ products { id name price category { id name } } }"
  }'
```

### JavaScriptでの実行例

```javascript
const query = `
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

fetch('http://localhost:4000/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ query })
})
.then(res => res.json())
.then(result => console.log(result));
```

## 開発ツール

### GraphQL Playground

開発環境では、`http://localhost:4000/graphiql` にアクセスすることで、インタラクティブなGraphQL Playgroundを使用できます。

機能：
- スキーマの探索
- 自動補完
- ドキュメントの参照
- クエリ履歴
- レスポンスのプレビュー

### スキーマの取得

イントロスペクションクエリでスキーマ全体を取得できます：

```graphql
query IntrospectionQuery {
  __schema {
    types {
      name
      kind
      description
      fields {
        name
        type {
          name
          kind
        }
      }
    }
  }
}
```

## パフォーマンス考慮事項

1. **クエリの深さ制限**: 過度にネストしたクエリは避けてください
2. **フィールド数の制限**: 一度のクエリで取得するフィールド数を適切に制限してください
3. **ページネーション**: 大量のデータを取得する場合は、ページネーションを使用してください

## 今後の拡張予定

- [ ] GraphQL Subscriptions（リアルタイム更新）
- [ ] ファイルアップロード
- [ ] カスタムディレクティブ
- [ ] 認証・認可
- [ ] レート制限
- [ ] クエリ複雑度の制限