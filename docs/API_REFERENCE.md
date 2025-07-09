# API リファレンス

## GraphQL API

エンドポイント: `http://localhost:4000/graphql`

### Queries

#### categories

全カテゴリを取得します。

```graphql
query {
  categories {
    id
    name
    description
    productCount
    createdAt
    updatedAt
  }
}
```

#### category

特定のカテゴリを取得します。

```graphql
query GetCategory($id: ID!) {
  category(id: $id) {
    id
    name
    description
    productCount
    parentId
    active
    createdAt
    updatedAt
  }
}
```

#### products

商品一覧を取得します。

```graphql
query {
  products(categoryId: "optional-category-id") {
    id
    name
    description
    price
    stockQuantity
    currency
    category {
      id
      name
    }
    createdAt
    updatedAt
  }
}
```

#### product

特定の商品を取得します。

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    description
    price
    stockQuantity
    currency
    categoryId
    active
    createdAt
    updatedAt
  }
}
```

### Mutations

#### createCategory

新しいカテゴリを作成します。

```graphql
mutation CreateCategory($input: CreateCategoryInput!) {
  createCategory(input: $input) {
    id
    name
    description
    productCount
    createdAt
  }
}

# Variables
{
  "input": {
    "name": "Electronics",
    "description": "Electronic devices and gadgets",
    "parentId": null
  }
}
```

#### updateCategory

既存のカテゴリを更新します。

```graphql
mutation UpdateCategory($id: ID!, $input: UpdateCategoryInput!) {
  updateCategory(id: $id, input: $input) {
    id
    name
    description
    updatedAt
  }
}

# Variables
{
  "id": "category-id",
  "input": {
    "name": "Updated Electronics",
    "description": "Updated description"
  }
}
```

#### deleteCategory

カテゴリを削除します。

```graphql
mutation DeleteCategory($id: ID!) {
  deleteCategory(id: $id) {
    success
    message
  }
}
```

#### createProduct

新しい商品を作成します。

```graphql
mutation CreateProduct($input: CreateProductInput!) {
  createProduct(input: $input) {
    id
    name
    description
    price
    stockQuantity
    categoryId
    createdAt
  }
}

# Variables
{
  "input": {
    "name": "MacBook Pro",
    "description": "High-performance laptop",
    "price": 299900,
    "stockQuantity": 10,
    "categoryId": "category-id"
  }
}
```

#### updateProduct

既存の商品を更新します。

```graphql
mutation UpdateProduct($id: ID!, $input: UpdateProductInput!) {
  updateProduct(id: $id, input: $input) {
    id
    name
    description
    price
    updatedAt
  }
}

# Variables
{
  "id": "product-id",
  "input": {
    "name": "MacBook Pro M3",
    "description": "Latest model with M3 chip",
    "price": 329900
  }
}
```

#### changeProductPrice

商品の価格を変更します。

```graphql
mutation ChangeProductPrice($id: ID!, $newPrice: Float!) {
  changeProductPrice(id: $id, newPrice: $newPrice) {
    id
    price
    updatedAt
  }
}
```

#### deleteProduct

商品を削除します。

```graphql
mutation DeleteProduct($id: ID!) {
  deleteProduct(id: $id) {
    success
    message
  }
}
```

## gRPC API

### Command Service (Port: 50051)

#### CategoryCommandService

```protobuf
service CategoryCommandService {
  rpc CreateCategory(CreateCategoryRequest) returns (CreateCategoryResponse);
  rpc UpdateCategory(UpdateCategoryRequest) returns (UpdateCategoryResponse);
  rpc DeleteCategory(DeleteCategoryRequest) returns (DeleteCategoryResponse);
}

message CreateCategoryRequest {
  string name = 1;
  string description = 2;
  string parent_id = 3;
}

message CreateCategoryResponse {
  Result result = 1;
  string id = 2;
}
```

#### ProductCommandService

```protobuf
service ProductCommandService {
  rpc CreateProduct(CreateProductRequest) returns (CreateProductResponse);
  rpc UpdateProduct(UpdateProductRequest) returns (UpdateProductResponse);
  rpc ChangeProductPrice(ChangeProductPriceRequest) returns (ChangeProductPriceResponse);
  rpc DeleteProduct(DeleteProductRequest) returns (DeleteProductResponse);
}

message CreateProductRequest {
  string name = 1;
  string description = 2;
  string price = 3;
  int32 stock_quantity = 4;
  string category_id = 5;
}

message CreateProductResponse {
  Result result = 1;
  string id = 2;
}
```

### Query Service (Port: 50052)

#### CategoryQueryService

```protobuf
service CategoryQueryService {
  rpc GetCategory(GetCategoryRequest) returns (GetCategoryResponse);
  rpc ListCategories(ListCategoriesRequest) returns (ListCategoriesResponse);
  rpc SearchCategories(SearchCategoriesRequest) returns (SearchCategoriesResponse);
}

message GetCategoryRequest {
  string id = 1;
}

message GetCategoryResponse {
  CategoryReadModel category = 1;
}

message ListCategoriesRequest {
  int32 page = 1;
  int32 page_size = 2;
}

message ListCategoriesResponse {
  repeated CategoryReadModel categories = 1;
  int32 total = 2;
}
```

#### ProductQueryService

```protobuf
service ProductQueryService {
  rpc GetProduct(GetProductRequest) returns (GetProductResponse);
  rpc ListProducts(ListProductsRequest) returns (ListProductsResponse);
  rpc SearchProducts(SearchProductsRequest) returns (SearchProductsResponse);
}

message GetProductRequest {
  string id = 1;
}

message GetProductResponse {
  ProductReadModel product = 1;
}

message ListProductsRequest {
  int32 page = 1;
  int32 page_size = 2;
  string category_id = 3;
}

message ListProductsResponse {
  repeated ProductReadModel products = 1;
  int32 total = 2;
}
```

## エラーコード

### GraphQL エラー

```json
{
  "errors": [
    {
      "message": "Command Service unavailable",
      "extensions": {
        "code": "SERVICE_UNAVAILABLE"
      }
    }
  ]
}
```

### gRPC エラー

| コード | 説明 |
|--------|------|
| `VALIDATION_ERROR` | 入力値の検証エラー |
| `NOT_FOUND` | リソースが見つからない |
| `COMMAND_FAILED` | コマンド実行の失敗 |
| `SAVE_FAILED` | データ保存の失敗 |
| `VERSION_CONFLICT` | 楽観的ロックの競合 |

## レート制限

現在、レート制限は実装されていません。本番環境では適切なレート制限の実装を推奨します。

## 認証

現在、認証は実装されていません。本番環境では適切な認証メカニズムの実装が必要です。