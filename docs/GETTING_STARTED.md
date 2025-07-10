# Getting Started

このドキュメントでは、Elixir CQRS プロジェクトの環境構築から動作確認までの手順を説明します。

## 前提条件

以下のツールがインストールされている必要があります：

- Elixir 1.18 以上
- Erlang/OTP 26 以上
- Docker Desktop
- PostgreSQL クライアント（psql）
- Git

## 環境構築

### 1. リポジトリのクローン

```bash
git clone [repository-url]
cd elixir-cqrs
```

### 2. 依存関係のインストール

```bash
# ルートディレクトリで実行
mix deps.get

# 各アプリケーションの依存関係も取得
mix deps.get --all
```

### 3. Docker コンテナの起動

```bash
# データベースと監視ツールを起動
docker compose up -d
```

以下のコンテナが起動します：

- PostgreSQL (3 インスタンス)
  - Event Store DB (ポート: 5432)
  - Command DB (ポート: 5433)
  - Query DB (ポート: 5434)
- Prometheus (ポート: 9090)
- Jaeger (ポート: 16686)
- Grafana (ポート: 3000)

### 4. データベースのセットアップ

```bash
# データベースの作成とマイグレーション
./scripts/setup_db.sh

# シードデータの投入（オプション）
./scripts/seed_db.sh
```

## サービスの起動

3 つのターミナルウィンドウを開いて、それぞれのサービスを起動します。

### ターミナル 1: Command Service

```bash
cd apps/command_service
iex -S mix
```

起動ログで以下を確認：

- `[info] Starting Command Service`
- `[info] Phoenix PubSub started`

### ターミナル 2: Query Service

```bash
cd apps/query_service
iex -S mix
```

起動ログで以下を確認：

- `[info] Starting Query Service`
- `[info] Processing X new events` (定期的なイベント処理)

### ターミナル 3: Client Service

```bash
cd apps/client_service
mix phx.server
```

起動ログで以下を確認：

- `[info] Running ClientServiceWeb.Endpoint with cowboy 2.x.x at 127.0.0.1:4000`

## 動作確認

### GraphQL Playground

ブラウザで http://localhost:4000/graphiql にアクセスします。

### カテゴリの作成

```graphql
mutation {
  createCategory(
    input: {
      name: "Electronics"
      description: "Electronic devices and gadgets"
    }
  ) {
    id
    name
    description
    productCount
    createdAt
  }
}
```

### カテゴリ一覧の取得

```graphql
query {
  categories {
    id
    name
    description
    productCount
  }
}
```

### 商品の作成

```graphql
mutation {
  createProduct(
    input: {
      name: "MacBook Pro"
      description: "High-performance laptop"
      price: 299900
      stockQuantity: 10
      categoryId: "[上記で作成したカテゴリのID]"
    }
  ) {
    id
    name
    description
    price
    stockQuantity
    categoryId
  }
}
```

### 商品一覧の取得

```graphql
query {
  products {
    id
    name
    description
    price
    stockQuantity
    category {
      name
    }
  }
}
```

## 監視ツールへのアクセス

- **Jaeger UI**: http://localhost:16686

  - 分散トレースの確認
  - サービス間の通信フローの可視化

- **Prometheus**: http://localhost:9090

  - メトリクスの確認
  - クエリの実行

- **Grafana**: http://localhost:3000
  - ダッシュボードの表示
  - デフォルト認証: admin/admin

## トラブルシューティング

### Phoenix PubSub 接続エラー

```
[error] Failed to send command: :timeout
```

**解決方法**:

1. すべてのサービスが起動していることを確認
2. 各サービスのログでエラーがないか確認
3. Docker コンテナが正常に動作しているか確認: `docker compose ps`

### データベース接続エラー

```
** (DBConnection.ConnectionError) connection not available
```

**解決方法**:

1. Docker コンテナが起動しているか確認
2. データベースのマイグレーションが完了しているか確認
3. 接続設定（ポート番号）が正しいか確認

### OTLP エクスポーターの警告

```
The OTLP exporter is sending telemetry to...
```

これは開発環境では正常な警告です。本番環境では適切な OpenTelemetry コレクターを設定してください。

## 次のステップ

- [アーキテクチャ概要](./ARCHITECTURE.md)
- [開発ガイド](./DEVELOPMENT.md)
- [API リファレンス](./API_GRAPHQL.md)
