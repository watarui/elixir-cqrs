# Elixir CQRS/ES/SAGA マイクロサービス

このプロジェクトは、Elixir/Phoenix を使用して CQRS (Command Query Responsibility Segregation)、Event Sourcing、SAGA パターンを実装したマイクロサービスアーキテクチャの学習用プロジェクトです。

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
   - gRPC サーバー（ポート: 50051）

3. **Query Service** - クエリ処理サービス
   - リードモデル
   - クエリハンドラー
   - プロジェクション
   - gRPC サーバー（ポート: 50052）

4. **Client Service** - クライアント向け API
   - GraphQL API（ポート: 4000）
   - gRPC クライアント

## 技術スタック

- **言語**: Elixir
- **フレームワーク**: Phoenix
- **データベース**: PostgreSQL
- **API**: GraphQL (Absinthe) + gRPC
- **メッセージング**: イベントバス（プロセス間通信）
- **監視**: OpenTelemetry + Jaeger + Prometheus + Grafana

## セットアップ

### 必要な環境

- Elixir 1.15+
- PostgreSQL 16+
- Docker & Docker Compose

### 手順

1. 依存関係のインストール
```bash
mix deps.get
```

2. データベースの起動
```bash
docker compose up -d
```

3. データベースのセットアップ
```bash
mix ecto.setup
```

4. アプリケーションの起動
```bash
mix phx.server
```

## API の使用方法

### GraphQL API

エンドポイント: `http://localhost:4000/api/graphql`

#### カテゴリー作成
```bash
curl -X POST http://localhost:4000/api/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createCategory(input: { name: \"電化製品\" }) { id name createdAt } }"
  }'
```

#### 商品作成
```bash
curl -X POST http://localhost:4000/api/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createProduct(input: { name: \"ノートパソコン\", price: 120000, categoryId: \"1\" }) { id name price { amount currency } } }"
  }'
```

#### 注文作成（SAGA パターン）
```bash
curl -X POST http://localhost:4000/api/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createOrder(input: { userId: \"user-123\", items: [{ productId: \"1\", quantity: 2, unitPrice: 120000 }] }) { orderId message } }"
  }'
```

### テストスクリプト

```bash
./scripts/test_api.sh
```

## 監視・デバッグ

### Jaeger（分散トレーシング）
- URL: http://localhost:16686
- サービス間の呼び出しをトレース

### Prometheus（メトリクス）
- URL: http://localhost:9090
- システムメトリクスの確認

### Grafana（ダッシュボード）
- URL: http://localhost:3000
- ログイン: admin/admin

## 開発

### テストの実行
```bash
mix test
```

### コード品質チェック
```bash
mix check
```

### マイグレーション
```bash
mix ecto.migrate
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
│   ├── command_service/ # コマンド処理
│   ├── query_service/   # クエリ処理
│   └── client_service/  # GraphQL API
├── config/              # 設定ファイル
├── docker-compose.yml   # Docker 設定
├── scripts/             # ユーティリティスクリプト
└── README.md
```

## ライセンス

このプロジェクトは学習目的で作成されています。