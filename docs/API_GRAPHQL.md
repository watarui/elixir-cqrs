# GraphQL API リファレンス

## エンドポイント

- **GraphQL Endpoint**: `http://localhost:4000/graphql`
- **GraphQL Playground**: `http://localhost:4000/graphiql`

## スキーマ概要

### Queries (読み取り)

#### カテゴリ関連

##### `category`

単一のカテゴリを取得します。

```graphql
query GetCategory($id: ID!) {
  category(id: $id) {
    id
    name
    description
    parentId
    active
    productCount
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

##### `categories`

カテゴリ一覧を取得します。

```graphql
query ListCategories(
  $limit: Int = 20
  $offset: Int = 0
  $sortBy: String = "name"
  $sortOrder: SortOrder = ASC
) {
  categories(
    limit: $limit
    offset: $offset
    sortBy: $sortBy
    sortOrder: $sortOrder
  ) {
    id
    name
    productCount
  }
}
```

##### `searchCategories`

カテゴリを検索します。

```graphql
query SearchCategories($searchTerm: String!) {
  searchCategories(searchTerm: $searchTerm) {
    id
    name
    description
  }
}
```

#### 商品関連

##### `product`

単一の商品を取得します。

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    description
    price
    currency
    categoryId
    category {
      id
      name
    }
    stockQuantity
    active
    createdAt
    updatedAt
  }
}
```

##### `products`

商品一覧を取得します。

```graphql
query ListProducts(
  $categoryId: ID
  $limit: Int = 20
  $offset: Int = 0
  $sortBy: String = "name"
  $sortOrder: SortOrder = ASC
  $minPrice: Decimal
  $maxPrice: Decimal
) {
  products(
    categoryId: $categoryId
    limit: $limit
    offset: $offset
    sortBy: $sortBy
    sortOrder: $sortOrder
    minPrice: $minPrice
    maxPrice: $maxPrice
  ) {
    id
    name
    price
    stockQuantity
  }
}
```

##### `searchProducts`

商品を検索します。

```graphql
query SearchProducts($searchTerm: String!, $categoryId: ID) {
  searchProducts(searchTerm: $searchTerm, categoryId: $categoryId) {
    id
    name
    price
    description
  }
}
```

### Mutations (書き込み)

#### カテゴリ関連

##### `createCategory`

新しいカテゴリを作成します。

```graphql
mutation CreateCategory($input: CreateCategoryInput!) {
  createCategory(input: $input) {
    id
    name
    description
    createdAt
  }
}

# 入力例
{
  "input": {
    "name": "家電",
    "description": "家電製品のカテゴリ",
    "parentId": null
  }
}
```

##### `updateCategory`

カテゴリを更新します。

```graphql
mutation UpdateCategory(
  $id: ID!
  $input: UpdateCategoryInput!
) {
  updateCategory(id: $id, input: $input) {
    id
    name
    description
    updatedAt
  }
}

# 入力例
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "input": {
    "name": "新しいカテゴリ名",
    "description": "更新された説明"
  }
}
```

##### `deleteCategory`

カテゴリを削除します。

```graphql
mutation DeleteCategory($id: ID!) {
  deleteCategory(id: $id) {
    success
    message
  }
}
```

#### 商品関連

##### `createProduct`

新しい商品を作成します。

```graphql
mutation CreateProduct($input: CreateProductInput!) {
  createProduct(input: $input) {
    id
    name
    price
    stockQuantity
    createdAt
  }
}

# 入力例
{
  "input": {
    "name": "ノートパソコン",
    "description": "高性能ノートPC",
    "price": 150000,
    "categoryId": "123e4567-e89b-12d3-a456-426614174000",
    "stockQuantity": 10
  }
}
```

##### `updateProduct`

商品を更新します。

```graphql
mutation UpdateProduct($id: ID!, $input: UpdateProductInput!) {
  updateProduct(id: $id, input: $input) {
    id
    name
    price
    updatedAt
  }
}
```

##### `changeProductPrice`

商品価格を変更します。

```graphql
mutation ChangeProductPrice($id: ID!, $newPrice: Decimal!) {
  changeProductPrice(id: $id, newPrice: $newPrice) {
    id
    price
    updatedAt
  }
}
```

##### `deleteProduct`

商品を削除します。

```graphql
mutation DeleteProduct($id: ID!) {
  deleteProduct(id: $id) {
    success
    message
  }
}
```

#### 注文関連

##### `createOrder`

新しい注文を作成し、SAGA パターンによる処理を開始します。

```graphql
mutation CreateOrder($input: CreateOrderInput!) {
  createOrder(input: $input) {
    id
    status
    totalAmount
    items {
      productId
      productName
      quantity
      unitPrice
      subtotal
    }
    createdAt
  }
}

# 入力例
{
  "input": {
    "userId": "user-123",
    "items": [
      {
        "productId": "123e4567-e89b-12d3-a456-426614174000",
        "productName": "スマートフォン",
        "quantity": 2,
        "unitPrice": 80000
      }
    ]
  }
}
```

**注意事項**:

- この mutation は SAGA パターンを使用して実行されます
- 在庫予約、支払い処理、注文確認の各ステップが順次実行されます
- いずれかのステップが失敗した場合、自動的に補償処理が実行されます
- 注文のステータスは初期状態では "pending" で、SAGA の完了後に "confirmed" または "cancelled" に更新されます

## 型定義

### Category

```graphql
type Category {
  id: ID!
  name: String!
  description: String
  parentId: ID
  active: Boolean
  productCount: Int
  products: [Product!]
  createdAt: DateTime!
  updatedAt: DateTime!
}
```

### Product

```graphql
type Product {
  id: ID!
  name: String!
  description: String
  price: Decimal!
  currency: String!
  categoryId: ID!
  category: Category
  stockQuantity: Int
  active: Boolean
  createdAt: DateTime!
  updatedAt: DateTime!
}
```

### Order

```graphql
type Order {
  id: ID!
  userId: String!
  status: OrderStatus!
  totalAmount: Decimal!
  items: [OrderItem!]!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type OrderItem {
  productId: ID!
  productName: String!
  quantity: Int!
  unitPrice: Decimal!
  subtotal: Decimal!
}

enum OrderStatus {
  PENDING
  CONFIRMED
  CANCELLED
  FAILED
}
```

### 入力型

#### CreateCategoryInput

```graphql
input CreateCategoryInput {
  name: String!
  description: String
  parentId: ID
}
```

#### UpdateCategoryInput

```graphql
input UpdateCategoryInput {
  name: String
  description: String
  parentId: ID
}
```

#### CreateProductInput

```graphql
input CreateProductInput {
  name: String!
  description: String
  price: Decimal!
  categoryId: ID!
  stockQuantity: Int
}
```

#### UpdateProductInput

```graphql
input UpdateProductInput {
  name: String
  description: String
  price: Decimal
  categoryId: ID
  stockQuantity: Int
}
```

#### CreateOrderInput

```graphql
input CreateOrderInput {
  userId: String!
  items: [OrderItemInput!]!
}

input OrderItemInput {
  productId: ID!
  productName: String!
  quantity: Int!
  unitPrice: Decimal!
}
```
