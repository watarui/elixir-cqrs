# Elixir CQRS Study Project

Elixir/Phoenix を使用した CQRS + イベントソーシング + サガパターンの学習用実装です。

## プロジェクト概要

マイクロサービスアーキテクチャにおける CQRS（コマンドクエリ責任分離）、イベントソーシング、およびサガパターンの実装を学習するためのサンプルプロジェクトです。

## 主な機能

- ✅ **完全な CQRS 実装** - コマンドとクエリの責任分離
- ✅ **イベントソーシング** - イベントベースの状態管理
- ✅ **サガパターン** - 分散トランザクションの管理
- ✅ **マイクロサービス** - 3 つの独立したサービス
- ✅ **GraphQL/gRPC** - モダンな API 通信
- ✅ **複数アイテム対応** - 並列処理を含む注文処理

## アーキテクチャ概要

```
┌─────────────────┐
│  Client (Web)   │
└────────┬────────┘
         │ GraphQL
┌────────▼────────┐
│ Client Service  │ Port: 4000
│   (API Gateway) │
└─┬──────────────┬┘
  │ gRPC         │ gRPC
┌─▼──────────┐ ┌─▼──────────┐
│  Command   │ │   Query    │
│  Service   │ │  Service   │
│ Port:50051 │ │ Port:50052 │
└─┬──────────┘ └──┬─────────┘
  │                │
┌─▼────────────────▼─┐
│   Event Store      │
│   (PostgreSQL)     │
│ Ports: 5432-5434   │
└────────────────────┘
```

## Quick Start

### Docker Compose による起動（推奨）

```bash
# 開発環境の起動（データベース作成・マイグレーション自動実行）
docker compose up -d

# ログの確認
docker compose logs -f

# 動作確認
curl http://localhost:4000/health
```

## API の使用例

### GraphQL Playground

http://localhost:4000/graphiql

### 商品カテゴリの作成

```graphql
mutation {
  createCategory(input: { name: "Electronics" }) {
    id
    name
  }
}
```

### 商品の作成

```graphql
mutation {
  createProduct(input: { name: "Laptop", price: 1500, categoryId: "cat-123" }) {
    id
    name
    price
  }
}
```

### 注文サガの開始（複数アイテム対応）

```graphql
mutation {
  startOrderSaga(
    input: {
      orderId: "order-001"
      userId: "user-123"
      items: [
        { productId: "prod-001", quantity: 2 }
        { productId: "prod-002", quantity: 1 }
      ]
      totalAmount: 3500.0
      shippingAddress: {
        street: "123 Main St"
        city: "Tokyo"
        postalCode: "100-0001"
      }
    }
  ) {
    sagaId
    success
    message
    startedAt
  }
}
```

## 実装されている機能詳細

### 1. Command Service (書き込み側)

- **コマンドハンドラー**: CategoryCommand, ProductCommand, OrderCommand
- **イベントストア**: PostgreSQL ベースの永続化
- **アグリゲート**: Category, Product の集約ルート
- **サガコーディネーター**: 分散トランザクションの管理

### 2. Query Service (読み取り側)

- **クエリハンドラー**: 非正規化されたビューの提供
- **プロジェクション**: イベントから読み取りモデルへの自動投影
- **キャッシュ**: ETS を使用した高速アクセス

### 3. サガパターンの実装

- **OrderSaga**: 注文処理の完全なフロー
  1. 在庫予約（並列処理対応）
  2. 支払い処理
  3. 配送手配
  4. 注文確定
- **自動補償**: 失敗時の自動ロールバック
- **タイムアウト管理**: 長時間実行の検出と処理

### 4. イベントソーシング

- **イベント永続化**: すべての状態変更をイベントとして記録
- **イベントリプレイ**: 過去の状態の再構築
- **スナップショット**: パフォーマンス最適化
- **ストリーム管理**: アグリゲートごとのイベントストリーム

## プロジェクト構造

```
elixir-cqrs/
├── apps/
│   ├── client_service/         # GraphQL API Gateway
│   │   ├── lib/
│   │   │   ├── graphql/       # GraphQLスキーマ・リゾルバー
│   │   │   ├── application/   # CQRSファサード
│   │   │   └── infrastructure/# gRPC接続管理
│   │   └── test/
│   │
│   ├── command_service/        # 書き込み専用サービス
│   │   ├── lib/
│   │   │   ├── domain/        # ドメイン層
│   │   │   │   ├── aggregates/# イベントソーシングアグリゲート
│   │   │   │   ├── commands/  # コマンド定義
│   │   │   │   └── events/    # ドメインイベント
│   │   │   ├── application/   # アプリケーション層
│   │   │   │   ├── handlers/  # コマンドハンドラー
│   │   │   │   └── command_bus.ex
│   │   │   └── infrastructure/# インフラ層
│   │   └── test/
│   │
│   ├── query_service/          # 読み取り専用サービス
│   │   ├── lib/
│   │   │   ├── domain/        # 読み取りモデル
│   │   │   ├── application/   # クエリハンドラー
│   │   │   └── infrastructure/# プロジェクション・キャッシュ
│   │   └── test/
│   │
│   └── shared/                 # 共有ライブラリ
│       ├── lib/
│       │   ├── domain/        # 共通ドメイン定義
│       │   │   └── saga/      # サガパターン基底クラス
│       │   └── infrastructure/# 共通インフラ
│       │       ├── event_store/# イベントストア実装
│       │       ├── saga/       # サガコーディネーター
│       │       └── telemetry/  # 監視・メトリクス
│       └── proto/             # Protocol Buffers定義
│
├── docker-compose.yml         # Docker設定
├── scripts/                   # 便利スクリプト
└── docs/                      # ドキュメント
```

## 技術スタック

- **言語**: Elixir 1.18 / Erlang OTP 27
- **フレームワーク**: Phoenix 1.7
- **データベース**: PostgreSQL 14
- **API**: GraphQL (Absinthe) / gRPC
- **イベントストア**: PostgreSQL ベース
- **コンテナ**: Docker / Docker Compose
- **監視**: Prometheus / OpenTelemetry

## テスト

```bash
# 全テストの実行
docker compose exec command-service mix test

# 特定のサービスのテスト
docker compose exec client-service mix test
docker compose exec query-service mix test

# SAGAの統合テスト（GraphQL経由）
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { startOrderSaga(input: {orderId: \"test-001\", userId: \"user-123\", items: [{productId: \"prod-001\", quantity: 1}], totalAmount: 100.0}) { sagaId success message } }"}'
```

## 開発者向け情報

### 新しいアグリゲートの追加

1. `apps/command_service/lib/command_service/domain/aggregates/` に新しいアグリゲートモジュールを作成
2. `Shared.Domain.Aggregate` ビヘイビアを実装
3. 対応するイベントとコマンドを定義

### 新しいサガの追加

1. `apps/shared/lib/shared/infrastructure/saga/` に新しいサガモジュールを作成
2. `use Shared.Domain.Saga.SagaDefinition` を使用
3. ステップと補償処理を定義

例：

```elixir
defmodule MyNewSaga do
  use Shared.Domain.Saga.SagaDefinition

  @impl true
  def steps do
    [
      %{
        step: :first_step,
        handler: &execute_first_step/1,
        compensation: &compensate_first_step/1
      }
    ]
  end
end
```

## 監視とデバッグ

### ログの確認

```bash
# 全サービスのログ
docker compose logs -f

# 特定サービスのログ
docker compose logs -f command-service
```

### データベースの確認

```bash
# イベントストアの確認
docker compose exec postgres-event psql -U postgres -d event_store

# イベントの一覧
SELECT * FROM events ORDER BY occurred_at DESC LIMIT 10;
```

## トラブルシューティング

### サービスが起動しない場合

```bash
# コンテナの再構築
docker compose down
docker compose build --no-cache
docker compose up -d
```

### データベース接続エラー

```bash
# データベースの初期化
docker compose exec postgres-command psql -U postgres -c "CREATE DATABASE command_service_dev;"
docker compose exec postgres-query psql -U postgres -c "CREATE DATABASE query_service_dev;"
docker compose exec postgres-event psql -U postgres -c "CREATE DATABASE event_store;"
```

## 参考資料

- [CQRS パターン](https://martinfowler.com/bliki/CQRS.html)
- [イベントソーシング](https://martinfowler.com/eaaDev/EventSourcing.html)
- [サガパターン](https://microservices.io/patterns/data/saga.html)
- [Elixir 公式ドキュメント](https://elixir-lang.org/docs.html)

## ライセンス

このプロジェクトは学習目的で作成されています。
