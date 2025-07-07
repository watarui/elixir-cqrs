# API 仕様書

## 概要

このドキュメントは、Elixir CQRS Event-Driven Microservices の GraphQL API の仕様を定義します。すべてのクライアントアプリケーションは、この API を通じてシステムと通信します。

## エンドポイント

### GraphQL エンドポイント

- **URL**: `http://localhost:4000/graphql`
- **Method**: POST
- **Content-Type**: `application/json`

### GraphQL Playground

- **URL**: `http://localhost:4000/graphiql`
- **環境**: 開発環境のみ

## 認証（将来実装）

```http
Authorization: Bearer <JWT_TOKEN>
```

## スキーマ定義

### スカラー型

```graphql
scalar DateTime
scalar Decimal
scalar UUID
```

## カテゴリ API

### Types

```graphql
type Category {
  id: ID!
  name: String!
  products: [Product!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

input CreateCategoryInput {
  name: String!
}

input UpdateCategoryInput {
  id: ID!
  name: String!
}
```

### Queries

#### カテゴリ取得

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

**Variables:**

```json
{
  "id": "1"
}
```

**Response:**

```json
{
  "data": {
    "category": {
      "id": "1",
      "name": "Electronics",
      "products": [
        {
          "id": "1",
          "name": "MacBook Pro",
          "price": 299000
        }
      ],
      "createdAt": "2024-01-15T10:00:00Z",
      "updatedAt": "2024-01-15T10:00:00Z"
    }
  }
}
```

#### カテゴリ一覧取得

```graphql
query ListCategories {
  categories {
    id
    name
    createdAt
    updatedAt
  }
}
```

**Response:**

```json
{
  "data": {
    "categories": [
      {
        "id": "1",
        "name": "Electronics",
        "createdAt": "2024-01-15T10:00:00Z",
        "updatedAt": "2024-01-15T10:00:00Z"
      },
      {
        "id": "2",
        "name": "Books",
        "createdAt": "2024-01-15T10:05:00Z",
        "updatedAt": "2024-01-15T10:05:00Z"
      }
    ]
  }
}
```

### Mutations

#### カテゴリ作成

```graphql
mutation CreateCategory($input: CreateCategoryInput!) {
  createCategory(input: $input) {
    id
    name
    createdAt
    updatedAt
  }
}
```

**Variables:**

```json
{
  "input": {
    "name": "Electronics"
  }
}
```

**Response:**

```json
{
  "data": {
    "createCategory": {
      "id": "3",
      "name": "Electronics",
      "createdAt": "2024-01-15T10:10:00Z",
      "updatedAt": "2024-01-15T10:10:00Z"
    }
  }
}
```

#### カテゴリ更新

```graphql
mutation UpdateCategory($input: UpdateCategoryInput!) {
  updateCategory(input: $input) {
    id
    name
    updatedAt
  }
}
```

**Variables:**

```json
{
  "input": {
    "id": "3",
    "name": "Consumer Electronics"
  }
}
```

#### カテゴリ削除

```graphql
mutation DeleteCategory($id: ID!) {
  deleteCategory(id: $id)
}
```

**Variables:**

```json
{
  "id": "3"
}
```

**Response:**

```json
{
  "data": {
    "deleteCategory": true
  }
}
```

## 商品 API

### Types

```graphql
type Product {
  id: ID!
  name: String!
  description: String
  price: Decimal!
  stockQuantity: Int!
  category: Category
  categoryId: ID
  createdAt: DateTime!
  updatedAt: DateTime!
}

input CreateProductInput {
  name: String!
  description: String
  price: Decimal!
  categoryId: ID
}

input UpdateProductInput {
  id: ID!
  name: String
  description: String
  price: Decimal
  categoryId: ID
}
```

### Queries

#### 商品取得

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    description
    price
    stockQuantity
    category {
      id
      name
    }
    createdAt
    updatedAt
  }
}
```

**Variables:**

```json
{
  "id": "1"
}
```

#### 商品一覧取得

```graphql
query ListProducts($categoryId: ID, $limit: Int, $offset: Int) {
  products(categoryId: $categoryId, limit: $limit, offset: $offset) {
    id
    name
    price
    stockQuantity
    category {
      id
      name
    }
  }
}
```

**Variables:**

```json
{
  "categoryId": "1",
  "limit": 10,
  "offset": 0
}
```

### Mutations

#### 商品作成

```graphql
mutation CreateProduct($input: CreateProductInput!) {
  createProduct(input: $input) {
    id
    name
    description
    price
    category {
      id
      name
    }
    createdAt
  }
}
```

**Variables:**

```json
{
  "input": {
    "name": "iPhone 15 Pro",
    "description": "Latest Apple smartphone",
    "price": 149900,
    "categoryId": "1"
  }
}
```

#### 商品更新

```graphql
mutation UpdateProduct($input: UpdateProductInput!) {
  updateProduct(input: $input) {
    id
    name
    price
    updatedAt
  }
}
```

**Variables:**

```json
{
  "input": {
    "id": "1",
    "price": 139900
  }
}
```

#### 商品削除

```graphql
mutation DeleteProduct($id: ID!) {
  deleteProduct(id: $id)
}
```

## 注文 API（サガパターン）

### Types

```graphql
type Order {
  id: ID!
  userId: ID!
  status: OrderStatus!
  totalAmount: Decimal!
  items: [OrderItem!]!
  sagaState: SagaState
  createdAt: DateTime!
  updatedAt: DateTime!
}

type OrderItem {
  productId: ID!
  productName: String!
  quantity: Int!
  price: Decimal!
  subtotal: Decimal!
}

type SagaState {
  state: String!
  status: SagaStatus!
  currentStep: String
  completedSteps: [String!]!
  failureReason: String
  startedAt: DateTime!
  completedAt: DateTime
}

enum OrderStatus {
  PENDING
  PROCESSING
  CONFIRMED
  SHIPPED
  DELIVERED
  CANCELLED
}

enum SagaStatus {
  STARTED
  RUNNING
  COMPLETED
  FAILED
  COMPENSATING
}

input CreateOrderInput {
  userId: ID!
  items: [OrderItemInput!]!
}

input OrderItemInput {
  productId: ID!
  quantity: Int!
}

input CancelOrderInput {
  orderId: ID!
  reason: String
}
```

### Queries

#### 注文取得

```graphql
query GetOrder($id: ID!) {
  order(id: $id) {
    id
    userId
    status
    totalAmount
    items {
      productId
      productName
      quantity
      price
      subtotal
    }
    sagaState {
      state
      status
      currentStep
      completedSteps
      failureReason
      startedAt
      completedAt
    }
    createdAt
    updatedAt
  }
}
```

#### ユーザーの注文一覧取得

```graphql
query ListUserOrders(
  $userId: ID!
  $status: OrderStatus
  $limit: Int
  $offset: Int
) {
  userOrders(userId: $userId, status: $status, limit: $limit, offset: $offset) {
    id
    status
    totalAmount
    items {
      productName
      quantity
      subtotal
    }
    createdAt
  }
}
```

#### サガステータス取得

```graphql
query GetSagaStatus($orderId: ID!) {
  sagaStatus(orderId: $orderId) {
    sagaId
    state
    currentStep
    completedSteps
    error
    startedAt
    completedAt
  }
}
```

### Mutations

#### 注文作成

```graphql
mutation CreateOrder($input: CreateOrderInput!) {
  createOrder(input: $input) {
    id
    status
    totalAmount
    sagaState {
      state
      status
      currentStep
      startedAt
    }
    items {
      productId
      productName
      quantity
      price
      subtotal
    }
  }
}
```

**Variables:**

```json
{
  "input": {
    "userId": "user-123",
    "items": [
      {
        "productId": "1",
        "quantity": 2
      },
      {
        "productId": "2",
        "quantity": 1
      }
    ]
  }
}
```

**Response:**

```json
{
  "data": {
    "createOrder": {
      "id": "order-456",
      "status": "PROCESSING",
      "totalAmount": 449700,
      "sagaState": {
        "state": "started",
        "status": "STARTED",
        "currentStep": "reserve_inventory",
        "startedAt": "2024-01-15T10:30:00Z"
      },
      "items": [
        {
          "productId": "1",
          "productName": "MacBook Pro",
          "quantity": 2,
          "price": 149900,
          "subtotal": 299800
        },
        {
          "productId": "2",
          "productName": "Magic Mouse",
          "quantity": 1,
          "price": 149900,
          "subtotal": 149900
        }
      ]
    }
  }
}
```

#### 注文キャンセル

```graphql
mutation CancelOrder($input: CancelOrderInput!) {
  cancelOrder(input: $input)
}
```

**Variables:**

```json
{
  "input": {
    "orderId": "order-456",
    "reason": "Customer request"
  }
}
```

## エラーハンドリング

### エラーレスポンス形式

```json
{
  "errors": [
    {
      "message": "Error message",
      "extensions": {
        "code": "ERROR_CODE",
        "field": "fieldName",
        "timestamp": "2024-01-15T10:30:00Z"
      },
      "path": ["mutation", "createProduct"],
      "locations": [{ "line": 2, "column": 3 }]
    }
  ]
}
```

### エラーコード

| コード                | 説明                   | HTTP ステータス |
| --------------------- | ---------------------- | --------------- |
| `UNAUTHENTICATED`     | 認証が必要             | 401             |
| `FORBIDDEN`           | アクセス権限なし       | 403             |
| `NOT_FOUND`           | リソースが見つからない | 404             |
| `VALIDATION_ERROR`    | 入力値が無効           | 400             |
| `CONFLICT`            | リソースの競合         | 409             |
| `INTERNAL_ERROR`      | サーバー内部エラー     | 500             |
| `SERVICE_UNAVAILABLE` | サービス利用不可       | 503             |

### バリデーションエラー例

```json
{
  "errors": [
    {
      "message": "Validation failed",
      "extensions": {
        "code": "VALIDATION_ERROR",
        "validationErrors": [
          {
            "field": "price",
            "message": "Price must be greater than 0"
          },
          {
            "field": "name",
            "message": "Name is required"
          }
        ]
      }
    }
  ]
}
```

## ページネーション

### Relay-style カーソルベースページネーション（将来実装）

```graphql
type ProductConnection {
  edges: [ProductEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type ProductEdge {
  cursor: String!
  node: Product!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

query ProductsWithPagination($first: Int, $after: String) {
  products(first: $first, after: $after) {
    edges {
      cursor
      node {
        id
        name
        price
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
    totalCount
  }
}
```

## サブスクリプション（将来実装）

### リアルタイム注文更新

```graphql
subscription OrderUpdates($orderId: ID!) {
  orderUpdated(orderId: $orderId) {
    id
    status
    sagaState {
      state
      currentStep
      completedSteps
    }
  }
}
```

### 在庫更新通知

```graphql
subscription StockUpdates($productIds: [ID!]!) {
  stockUpdated(productIds: $productIds) {
    productId
    newQuantity
    updatedAt
  }
}
```

## レート制限（将来実装）

### レート制限ヘッダー

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642252800
```

### レート制限エラー

```json
{
  "errors": [
    {
      "message": "Too many requests",
      "extensions": {
        "code": "RATE_LIMIT_EXCEEDED",
        "retryAfter": 60
      }
    }
  ]
}
```

## ベストプラクティス

### 1. クエリの最適化

```graphql
# 良い例：必要なフィールドのみ取得
query GetProductMinimal($id: ID!) {
  product(id: $id) {
    id
    name
    price
  }
}

# 悪い例：不必要に深いネスト
query GetProductDeep($id: ID!) {
  product(id: $id) {
    category {
      products {
        category {
          products {
            # 深すぎる
          }
        }
      }
    }
  }
}
```

### 2. バッチリクエスト

```graphql
# 複数の操作を1回のリクエストで
mutation BatchOperations {
  createCategory1: createCategory(input: { name: "Category 1" }) {
    id
  }
  createCategory2: createCategory(input: { name: "Category 2" }) {
    id
  }
}
```

### 3. エラーハンドリング

```javascript
// クライアント側のエラーハンドリング例
const result = await client.mutate({
  mutation: CREATE_PRODUCT,
  variables: { input },
});

if (result.errors) {
  const validationErrors = result.errors
    .filter((e) => e.extensions.code === "VALIDATION_ERROR")
    .flatMap((e) => e.extensions.validationErrors);

  // バリデーションエラーの表示
  displayValidationErrors(validationErrors);
}
```

## 開発者向けツール

### GraphQL Playground 機能

- **自動補完**: スキーマベースの自動補完
- **ドキュメント**: インタラクティブなスキーマドキュメント
- **履歴**: クエリ実行履歴
- **変数エディタ**: JSON フォーマットの変数編集

### イントロスペクション

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

## バージョニング戦略

### 後方互換性の維持

1. **フィールドの追加**: 既存のクライアントに影響なし
2. **フィールドの削除**: 非推奨化後、移行期間を設けて削除
3. **型の変更**: 新しいフィールドを追加し、古いフィールドを非推奨化

### 非推奨化の例

```graphql
type Product {
  id: ID!
  name: String!
  price: Decimal! @deprecated(reason: "Use priceInfo.amount instead")
  priceInfo: PriceInfo! # 新しいフィールド
}
```

## セキュリティガイドライン

### 1. クエリの深さ制限

最大クエリ深さ: 10 レベル

### 2. クエリの複雑さ制限

最大クエリ複雑度: 1000 ポイント

### 3. インジェクション対策

- すべての入力値は自動的にサニタイズ
- SQL インジェクション対策済み

### 4. 認可チェック

各リゾルバーでユーザー権限を確認
