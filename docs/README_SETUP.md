# Elixir CQRS セットアップガイド

## 初期セットアップ

### 1. 依存関係のインストール

```bash
# プロジェクトルートで実行
mix deps.get
```

### 2. Proto ファイルのコンパイル

```bash
# protoc がインストールされていることを確認
# Mac の場合: brew install protobuf

# Proto ファイルをコンパイル
./scripts/generate_proto.sh
```

### 3. データベースのセットアップ

```bash
# Docker Compose でデータベースを起動
docker compose up -d postgres_event postgres_command postgres_query

# データベースの作成とマイグレーション
./scripts/setup_databases.sh
```

### 4. サービスの起動

#### 方法1: 個別に起動

```bash
# ターミナル1: Command Service
cd apps/command_service
mix grpc.server

# ターミナル2: Query Service
cd apps/query_service
mix grpc.server

# ターミナル3: Client Service (GraphQL)
cd apps/client_service
mix phx.server
```

#### 方法2: Docker Compose で起動

```bash
docker compose up
```

### 5. 動作確認

#### シードデータの投入

```bash
mix run scripts/seed_data.exs
```

#### GraphQL Playground

ブラウザで http://localhost:4000/graphql にアクセス

#### サンプルクエリ

```graphql
# カテゴリ一覧を取得
query {
  categories {
    id
    name
    description
    productCount
  }
}

# 商品一覧を取得
query {
  products {
    id
    name
    price {
      amount
      currency
    }
    category {
      name
    }
  }
}

# カテゴリを作成
mutation {
  createCategory(input: {
    name: "New Category"
    description: "A new category"
  }) {
    id
    name
  }
}

# 商品を作成
mutation {
  createProduct(input: {
    name: "New Product"
    categoryId: "カテゴリID"
    price: 1000
  }) {
    id
    name
    price {
      amount
    }
  }
}
```

## トラブルシューティング

### Proto ファイルのコンパイルエラー

```bash
# protoc-gen-elixir プラグインをインストール
mix escript.install hex protobuf
```

### データベース接続エラー

```bash
# PostgreSQL が起動していることを確認
docker compose ps

# ログを確認
docker compose logs postgres_event
```

### ポート競合

設定ファイル `config/config.exs` でポート番号を変更できます：
- Command Service gRPC: 50051
- Query Service gRPC: 50052
- Client Service HTTP: 4000