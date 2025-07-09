# Elixir CQRS/ES/SAGA マイクロサービス

このプロジェクトは、Elixir/Phoenix を使用して CQRS (Command Query Responsibility Segregation)、Event Sourcing、SAGA パターンを実装したマイクロサービスアーキテクチャの学習用プロジェクトです。

## クイックスタート

```bash
# 依存関係のインストール
mix deps.get

# コンパイル
mix compile

# Docker コンテナの起動
docker compose up -d

# データベースのセットアップ
./scripts/setup_db.sh

# サービスの起動
./scripts/start_services.sh

# または個別に起動する場合（3つのターミナルで実行）
# Terminal 1: Command Service
cd apps/command_service && mix run --no-halt

# Terminal 2: Query Service
cd apps/query_service && mix run --no-halt

# Terminal 3: Client Service
cd apps/client_service && mix phx.server
```

GraphQL Playground: http://localhost:4000/graphiql

詳細な手順は [Getting Started Guide](./docs/GETTING_STARTED.md) を参照してください。

## アーキテクチャ

### マイクロサービス構成

1. **Shared** - 共通ライブラリ
   - 値オブジェクト（Money、EntityId など）
   - ドメインイベント定義
   - イベントストア実装
   - SAGA基盤

2. **Command Service** - コマンド処理サービス
   - アグリゲート実装（Category、Product、Order）
   - コマンドハンドラー
   - SAGA実装（OrderSaga）
   - Phoenix PubSub 経由でイベントを受信

3. **Query Service** - クエリ処理サービス
   - リードモデル
   - クエリハンドラー
   - プロジェクション
   - Phoenix PubSub 経由でクエリを受信

4. **Client Service** - クライアント向け API
   - GraphQL API（ポート: 4000）
   - Phoenix PubSub を使用した非同期通信

## 技術スタック

- **言語**: Elixir 1.18+
- **フレームワーク**: Phoenix Framework
- **データベース**: PostgreSQL 16+ (3つのインスタンス)
- **API**: 
  - GraphQL (Absinthe) - クライアント向け API
  - Phoenix PubSub - マイクロサービス間通信
- **イベントストア**: PostgreSQL ベースの実装
- **監視**: 
  - OpenTelemetry - 分散トレーシング
  - Jaeger - トレース可視化
  - Prometheus - メトリクス収集
  - Grafana - ダッシュボード

## ドキュメント

- [Getting Started](./docs/GETTING_STARTED.md) - 環境構築と起動手順
- [アーキテクチャ概要](./docs/ARCHITECTURE.md) - システム設計と構成
- [開発ガイド](./docs/DEVELOPMENT.md) - 開発規約と新機能の追加方法
- [API リファレンス](./docs/API_REFERENCE.md) - GraphQL API の詳細

## API の使用例

### GraphQL Playground

http://localhost:4000/graphiql でインタラクティブな GraphQL Playground が利用できます。

### カテゴリ作成

```graphql
mutation {
  createCategory(input: {
    name: "Electronics"
    description: "Electronic devices and gadgets"
  }) {
    id
    name
    description
    productCount
  }
}
```

### 商品作成

```graphql
mutation {
  createProduct(input: {
    name: "MacBook Pro"
    description: "High-performance laptop"
    price: 299900
    stockQuantity: 10
    categoryId: "category-id-here"
  }) {
    id
    name
    price
    stockQuantity
  }
}
```

詳細な API ドキュメントは [API Reference](./docs/API_REFERENCE.md) を参照してください。

## 監視ツール

| ツール | URL | 用途 |
|--------|-----|------|
| Jaeger | http://localhost:16686 | 分散トレーシング |
| Prometheus | http://localhost:9090 | メトリクス収集 |
| Grafana | http://localhost:3000 | ダッシュボード（admin/admin） |

## 開発

```bash
# テストの実行
mix test

# コード品質チェック
mix format           # コードフォーマット
mix credo --strict   # 静的解析
mix dialyzer         # 型チェック

# カバレッジレポート
mix coveralls.html
```

## 主要な設計パターン

### CQRS (Command Query Responsibility Segregation)
- コマンド（書き込み）とクエリ（読み取り）を分離
- Command Service が書き込みを、Query Service が読み取りを担当

### Event Sourcing
- 状態変更をイベントとして保存
- イベントストアから集約を再構築

### SAGA Pattern
- 分散トランザクションの管理
- OrderSaga で注文処理フローを実装
- 補償トランザクションによるロールバック

### 値オブジェクト
- Money: 日本円の金額管理
- EntityId: UUID ベースの ID
- ProductName, CategoryName: ビジネスルールを含む文字列

## プロジェクト構造

```
elixir-cqrs/
├── apps/
│   ├── shared/          # 共通ライブラリ
│   │   ├── domain/      # ドメインモデル（値オブジェクト、イベント）
│   │   └── infrastructure/ # イベントストア、テレメトリー
│   ├── command_service/ # コマンド処理
│   │   ├── application/ # コマンドハンドラー
│   │   ├── domain/      # アグリゲート
│   │   └── presentation/ # gRPC サーバー
│   ├── query_service/   # クエリ処理
│   │   ├── application/ # クエリハンドラー
│   │   ├── infrastructure/ # プロジェクション、リポジトリ
│   │   └── presentation/ # gRPC サーバー
│   └── client_service/  # GraphQL API
│       └── graphql/     # スキーマ、リゾルバー
├── config/              # 設定ファイル
├── docker-compose.yml   # Docker 設定
├── scripts/             # ユーティリティスクリプト
├── proto/               # Protocol Buffers 定義
├── docs/                # ドキュメント
└── README.md
```

## ライセンス

このプロジェクトは学習目的で作成されています。