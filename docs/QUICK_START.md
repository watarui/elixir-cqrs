# クイックスタートガイド

このガイドでは、Elixir CQRS プロジェクトを最速で動かす手順を説明します。

## 前提条件

- Elixir 1.18 以上
- Erlang/OTP 26 以上
- Docker と Docker Compose
- PostgreSQL クライアント（psql）
- Git

## セットアップ手順

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd elixir-cqrs
```

### 2. 依存関係のインストール

```bash
mix deps.get
```

### 3. Docker コンテナの起動

```bash
docker compose up -d
```

これにより以下のサービスが起動します：

- PostgreSQL x3 (コマンド用、クエリ用、イベントストア用)
- Jaeger (分散トレーシング)
- Prometheus (メトリクス収集)
- Grafana (ダッシュボード)

### 4. データベースのセットアップ

```bash
./scripts/setup_db.sh
```

### 5. アプリケーションの起動

```bash
./scripts/start_services.sh
```

## 動作確認

### GraphQL Playground

ブラウザで http://localhost:4000/graphiql にアクセスします。

### サンプルクエリ

#### カテゴリの作成

```graphql
mutation {
  createCategory(input: { name: "家電", description: "家電製品のカテゴリ" }) {
    id
    name
    description
  }
}
```

#### 商品の作成

```graphql
mutation {
  createProduct(
    input: {
      name: "ノートパソコン"
      description: "高性能ノートPC"
      price: 150000
      stockQuantity: 10
      categoryId: "上で作成したカテゴリのID"
    }
  ) {
    id
    name
    price
    stockQuantity
  }
}
```

#### カテゴリ一覧の取得

```graphql
query {
  categories {
    id
    name
    productCount
  }
}
```

## 監視ツール

- **Jaeger UI**: http://localhost:16686

  - 分散トレースの確認
  - サービス間の通信フローの可視化

- **Prometheus**: http://localhost:9090

  - メトリクスの確認
  - クエリの実行

- **Grafana**: http://localhost:3000
  - ダッシュボードの表示
  - デフォルト認証: admin/admin
