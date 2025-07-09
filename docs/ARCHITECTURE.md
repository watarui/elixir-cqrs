# アーキテクチャ概要

## システム構成

このプロジェクトは、CQRS (Command Query Responsibility Segregation) とイベントソーシングパターンを採用した Elixir アプリケーションです。

```
┌─────────────────┐     GraphQL      ┌─────────────────┐
│                 │ ◄──────────────► │                 │
│  Client Service │                  │   Web Client    │
│  (Phoenix/GraphQL)                 │                 │
└────────┬────────┘                  └─────────────────┘
         │
         │ gRPC
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────────────┐     ┌─────────────────┐
│ Command Service │     │  Query Service  │
│   (Write Side)  │     │  (Read Side)    │
└────────┬────────┘     └────────┬────────┘
         │                       │
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│   Event Store   │     │ Read Model DB   │
│   (PostgreSQL)  │     │  (PostgreSQL)   │
└─────────────────┘     └─────────────────┘
```

## サービス構成

### 1. Client Service (apps/client_service)

- **役割**: Web API レイヤー
- **技術スタック**: Phoenix Framework, Absinthe (GraphQL)
- **ポート**: 4000
- **責務**:
  - GraphQL API の提供
  - gRPC クライアントによるバックエンドサービスとの通信
  - 認証・認可（未実装）

### 2. Command Service (apps/command_service)

- **役割**: 書き込み処理とビジネスロジック
- **技術スタック**: gRPC サーバー
- **ポート**: 50051
- **主要コンポーネント**:
  - **CommandBus**: コマンドのルーティング
  - **CommandHandlers**: コマンドの処理
  - **Aggregates**: ドメインロジックとイベントの生成
  - **EventStore**: イベントの永続化

### 3. Query Service (apps/query_service)

- **役割**: 読み取り専用のデータ提供
- **技術スタック**: gRPC サーバー
- **ポート**: 50052
- **主要コンポーネント**:
  - **QueryBus**: クエリのルーティング
  - **QueryHandlers**: クエリの処理
  - **ProjectionManager**: イベントから Read Model への変換
  - **Repositories**: Read Model からのデータ取得

### 4. Shared (apps/shared)

- **役割**: 共通ライブラリ
- **提供する機能**:
  - ドメインイベント定義
  - 値オブジェクト
  - イベントストア実装
  - テレメトリー設定
  - Protocol Buffers 定義

## データフロー

### 書き込みフロー

1. クライアントが GraphQL Mutation を送信
2. Client Service が gRPC でコマンドを Command Service に送信
3. CommandBus がコマンドを適切なハンドラーにルーティング
4. CommandHandler がアグリゲートを読み込み、コマンドを実行
5. アグリゲートがイベントを生成
6. イベントが Event Store に保存
7. イベントがイベントバスに発行

### 読み取りフロー

1. ProjectionManager が Event Store から新しいイベントを定期的に取得
2. 各 Projection がイベントを処理し、Read Model を更新
3. クライアントが GraphQL Query を送信
4. Client Service が gRPC でクエリを Query Service に送信
5. QueryHandler が Read Model からデータを取得
6. 結果がクライアントに返される

## ドメインモデル

### Category (カテゴリ)

- **属性**: id, name, description, parent_id, active
- **イベント**: CategoryCreated, CategoryUpdated, CategoryDeleted

### Product (商品)

- **属性**: id, name, description, price, stock_quantity, category_id
- **イベント**: ProductCreated, ProductUpdated, ProductPriceChanged, ProductDeleted, StockUpdated

### Order (注文)

- **属性**: id, customer_id, items, total_amount, status
- **イベント**: OrderCreated, OrderConfirmed, OrderCancelled
- **サガ**: OrderFulfillmentSaga（未実装）

## 技術的な設計判断

### なぜ CQRS？

- **スケーラビリティ**: 読み取りと書き込みを独立してスケール可能
- **パフォーマンス**: Read Model を最適化してクエリ性能を向上
- **柔軟性**: 異なる要件に応じて読み取り側と書き込み側を最適化

### なぜイベントソーシング？

- **監査証跡**: すべての変更履歴を保持
- **時系列分析**: 任意の時点の状態を再現可能
- **イベント駆動**: 他のシステムとの統合が容易

### なぜ gRPC？

- **型安全性**: Protocol Buffers による厳密な型定義
- **パフォーマンス**: バイナリプロトコルによる高速通信
- **ストリーミング**: 将来的なリアルタイム機能の実装が容易

## 拡張ポイント

1. **認証・認可**: Guardian または独自実装の追加
2. **キャッシング**: ETS または Redis の導入
3. **サガ実装**: 複雑なビジネスプロセスの処理
4. **イベントストリーミング**: Kafka や RabbitMQ との統合
5. **マルチテナント**: テナント分離の実装