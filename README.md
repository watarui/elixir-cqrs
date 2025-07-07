# Elixir CQRS Event-Driven Microservices

Elixir/Phoenix を使用した本格的な CQRS（Command Query Responsibility Segregation）+ イベントソーシング + サガパターンの実装例です。

## 🎯 プロジェクト概要

このプロジェクトは、モダンなマイクロサービスアーキテクチャのベストプラクティスを実装した、実践的な E コマースシステムのバックエンドです。

### 主要コンポーネント

- **Client Service** (GraphQL API Gateway) - ポート 4000
- **Command Service** (書き込み専用 gRPC) - ポート 50051
- **Query Service** (読み取り専用 gRPC) - ポート 50052
- **PostgreSQL** (Event Store + Read Models) - ポート 5432-5434
- **監視スタック** (Prometheus, Grafana, Jaeger)

## 🏗️ アーキテクチャ

### システム全体図

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend Applications                     │
└────────────────────────────┬─────────────────────────────────────┘
                             │ GraphQL
                    ┌────────▼────────┐
                    │ Client Service  │
                    │  (API Gateway)  │
                    └───┬─────────┬───┘
                        │         │ gRPC
         ┌──────────────▼─┐   ┌───▼──────────────┐
         │Command Service │   │ Query Service    │
         │   (Write)      │   │   (Read)         │
         └──────┬─────────┘   └────────┬─────────┘
                │                      │
     ┌──────────▼──────────┐  ┌────────▼────────┐
     │   Event Store       │  │  Read Models    │
     │   (PostgreSQL)      │  │  (PostgreSQL)   │
     └─────────────────────┘  └─────────────────┘
```

### CQRS + Event Sourcing アーキテクチャ

```
Write Side (Command)                    Read Side (Query)
┌─────────────────────┐                ┌─────────────────────┐
│   GraphQL Mutation  │                │   GraphQL Query     │
└──────────┬──────────┘                └──────────┬──────────┘
           │                                      │
    ┌──────▼──────┐                        ┌──────▼──────┐
    │   Command   │                        │    Query    │
    └──────┬──────┘                        └──────┬──────┘
           │                                      │
    ┌──────▼──────┐                        ┌──────▼──────┐
    │  Aggregate  │                        │ Read Model  │
    └──────┬──────┘                        └──────▲──────┘
           │                                      │
    ┌──────▼──────┐         ┌──────────┐  ┌──────┴──────┐
    │   Domain    │────────▶│  Event   │─▶│ Projection  │
    │   Event     │         │  Store   │  │  Manager    │
    └─────────────┘         └──────────┘  └─────────────┘
```

### サガパターン（分散トランザクション）

```
Order Saga Flow:
┌─────────────┐
│Create Order │
└──────┬──────┘
       │
   ┌───▼───┐     Success      ┌──────────────┐
   │Reserve├─────────────────▶│Process       │
   │Stock  │                  │Payment       │
   └───┬───┘                  └──────┬───────┘
       │ Fail                        │ Success
       │                             │
   ┌───▼───────┐              ┌──────▼───────┐
   │Compensate │              │Arrange       │
   │(Cancel)   │              │Shipping      │
   └───────────┘              └──────┬───────┘
                                     │
                              ┌──────▼───────┐
                              │Confirm Order │
                              └──────────────┘
```

## 🚀 Quick Start

### Docker Compose による起動（推奨）

```bash
# 開発環境の起動
docker compose up -d

# 監視スタックも含めて起動
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d

# ログの確認
docker compose logs -f
```

### 手動セットアップ

#### 前提条件

- Elixir 1.18+
- PostgreSQL 14+
- protoc (Protocol Buffers コンパイラ)
- protoc-gen-elixir

#### データベースセットアップ

```bash
# データベース作成
createdb command_service_dev
createdb query_service_dev
createdb event_store_dev

# マイグレーション実行
cd apps/command_service && mix ecto.migrate
cd apps/query_service && mix ecto.migrate
cd apps/shared && MIX_ENV=dev mix ecto.migrate -r Shared.Infrastructure.EventStore.Repo
```

#### サービス起動

```bash
# 依存関係のインストール
mix deps.get

# 各サービスを個別のターミナルで起動
# Terminal 1: Query Service
cd apps/query_service && mix run --no-halt

# Terminal 2: Command Service
cd apps/command_service && mix run --no-halt

# Terminal 3: Client Service
cd apps/client_service && mix phx.server
```

## 📡 API 使用例

### GraphQL Playground

開発環境では、GraphQL Playground が利用可能です：

- URL: http://localhost:4000/graphiql

### 基本的な CRUD 操作

#### カテゴリ作成

```graphql
mutation {
  createCategory(input: { name: "Electronics" }) {
    id
    name
  }
}
```

#### 商品作成

```graphql
mutation {
  createProduct(
    input: { name: "MacBook Pro", price: 299000, categoryId: "1" }
  ) {
    id
    name
    price
    category {
      name
    }
  }
}
```

#### 商品一覧取得

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

### 注文処理（サガパターン）

```graphql
mutation {
  createOrder(
    input: { userId: "user-123", items: [{ productId: "1", quantity: 1 }] }
  ) {
    id
    status
    totalAmount
    sagaState {
      state
      status
      currentStep
      startedAt
      completedAt
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

## 🔍 主要機能

### ✅ 実装済み

#### コアアーキテクチャ

- **CQRS（Command Query Responsibility Segregation）**

  - コマンドバス（メディエーターパターン）
  - クエリバス（並列実行サポート）
  - 統一 CQRS ファサード

- **イベントソーシング**

  - イベントストア（PostgreSQL 実装）
  - アグリゲート基底クラス
  - イベント駆動アーキテクチャ
  - プロジェクション自動更新

- **サガパターン**
  - 分散トランザクション管理
  - 補償トランザクション（設計済み）
  - ステート管理
  - タイムアウト処理

#### インフラストラクチャ

- **マイクロサービス間通信**

  - gRPC（Protocol Buffers）
  - GraphQL API Gateway
  - 非同期メッセージング

- **レジリエンス**

  - サーキットブレーカー
  - リトライ機構（エクスポネンシャルバックオフ）
  - タイムアウト管理
  - エラーハンドリング統一

- **監視・可観測性**
  - OpenTelemetry 統合
  - 分散トレーシング（Jaeger）
  - メトリクス収集（Prometheus）
  - ダッシュボード（Grafana）
  - 構造化ログ

#### データ管理

- **リポジトリパターン**

  - Unit of Work
  - トランザクション管理
  - キャッシング戦略

- **パフォーマンス最適化**
  - BatchCache（N+1 問題解決）
  - ETS インメモリキャッシュ
  - GraphQL DataLoader 統合

### 🚧 実装予定

- 認証・認可（JWT/OAuth2）
- GraphQL Subscriptions（リアルタイム更新）
- イベントバージョニング
- スナップショット機能
- マルチテナント対応

## 📁 プロジェクト構造

```
elixir-cqrs/
├── apps/
│   ├── client_service/         # GraphQL API Gateway
│   │   ├── graphql/           # GraphQLスキーマ・リゾルバー
│   │   ├── application/       # CQRSファサード
│   │   └── infrastructure/    # gRPC接続管理
│   │
│   ├── command_service/        # 書き込み専用サービス
│   │   ├── domain/            # ドメイン層
│   │   │   ├── aggregates/    # イベントソーシングアグリゲート
│   │   │   ├── commands/      # コマンド定義
│   │   │   └── events/        # ドメインイベント
│   │   ├── application/       # アプリケーション層
│   │   │   ├── handlers/      # コマンドハンドラー
│   │   │   └── command_bus.ex # コマンドバス
│   │   └── infrastructure/    # インフラ層
│   │
│   ├── query_service/          # 読み取り専用サービス
│   │   ├── domain/            # 読み取りモデル
│   │   ├── application/       # クエリハンドラー
│   │   └── infrastructure/    # キャッシュ・リポジトリ
│   │
│   └── shared/                 # 共有ライブラリ
│       ├── domain/            # 共通ドメイン定義
│       ├── infrastructure/    # 共通インフラ
│       │   ├── event_store/   # イベントストア
│       │   ├── saga/          # サガパターン実装
│       │   └── telemetry/     # 監視・メトリクス
│       └── proto/             # Protocol Buffers定義
│
├── docker/                     # Docker設定
├── k8s/                       # Kubernetes マニフェスト
└── docs/                      # ドキュメント
```

## 🛠️ 技術スタック

### 言語・フレームワーク

- **Elixir** 1.18 - 高い並行性と耐障害性
- **Phoenix** 1.7 - Web フレームワーク
- **Absinthe** - GraphQL 実装
- **grpc-elixir** - gRPC 通信

### データストア

- **PostgreSQL** 14 - イベントストア、読み取りモデル
- **ETS** - インメモリキャッシュ

### インフラ・監視

- **Docker** & **Docker Compose** - コンテナ化
- **Kubernetes** - オーケストレーション（マニフェスト準備済み）
- **OpenTelemetry** - 分散トレーシング
- **Prometheus** - メトリクス収集
- **Grafana** - ダッシュボード
- **Jaeger** - 分散トレース可視化

## 📊 監視・運用

### メトリクスエンドポイント

- Client Service: http://localhost:4000/metrics
- Command Service: http://localhost:9569/metrics
- Query Service: http://localhost:9570/metrics

### 監視ダッシュボード

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)
- Jaeger: http://localhost:16686

## 🧪 テスト

```bash
# 全テストの実行
mix test

# カバレッジレポート付き
mix test --cover

# 特定のサービスのテスト
cd apps/command_service && mix test
```

## 📚 ドキュメント

- [アーキテクチャ設計書](docs/architecture.md)
- [API 仕様書](docs/api-specification.md)
- [サガパターン実装ガイド](docs/saga-pattern.md)
- [イベントソーシングガイド](docs/event-sourcing.md)
- [運用マニュアル](docs/operations.md)
