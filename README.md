# Elixir CQRS マイクロサービス

Elixir/Phoenix を使用した CQRS（Command Query Responsibility Segregation）パターンの実装例です。

## プロジェクト概要

このプロジェクトは、次の 3 つのマイクロサービスで構成されています：

- **Client Service** (GraphQL API) - ポート 4000
- **Command Service** (gRPC) - ポート 50051
- **Query Service** (gRPC) - ポート 50052

## 現在の状況

✅ **すべてのサービスが正常に動作中**

### 動作確認済み機能

- [x] Client Service HTTP サーバー起動（ポート 4000）
- [x] Phoenix Endpoint 設定
- [x] GraphQL API エンドポイント（`/graphql`）
- [x] ヘルスチェック エンドポイント（`/health`）
- [x] gRPC 接続（Client → Command/Query Services）
- [x] GraphQL スキーマ定義
- [x] Category データの取得・表示
- [x] Product データの取得・表示（カテゴリ情報含む）
- [x] 複合クエリの実行
- [x] Command Service（ポート 50051）
- [x] Query Service（ポート 50052）

## アーキテクチャ

```
[Client Service:4000]  ←→  HTTP/GraphQL  ←→  [Web Client]
         ↓
      gRPC calls
         ↓
[Command Service:50051] ←→ [Database]
[Query Service:50052]  ←→ [Database]
```

## クイックスタート

### 前提条件

- Elixir 1.14+
- PostgreSQL
- 依存関係: `mix deps.get`

### データベース設定

```bash
# Command Service用データベース
cd apps/command_service
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

# Query Service用データベース
cd ../query_service
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

### サービス起動

**ターミナル 1: Query Service**

```bash
cd apps/query_service
mix run --no-halt
```

**ターミナル 2: Command Service**

```bash
cd apps/command_service
mix run --no-halt
```

**ターミナル 3: Client Service**

```bash
cd apps/client_service
mix phx.server
```

### 動作確認

#### 1. ヘルスチェック

```bash
curl http://localhost:4000/health
```

#### 2. カテゴリ一覧取得

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ categories { id name } }"}'
```

#### 3. 商品一覧取得（カテゴリ情報含む）

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ products { id name price category { id name } } }"}'
```

#### 4. 複合クエリ

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ categories { id name } products { id name price category { id name } } }"}'
```

## 解決された問題

### 主要な修正事項

1. **Client Service 起動問題**

   - `mix.exs`の`config_path`設定修正
   - Phoenix 設定の最適化
   - Application 起動順序の調整

2. **gRPC 通信問題**

   - Query/Command Service の gRPC サーバー実装
   - protobuf エンコーディングエラー修正
   - Client Service の gRPC 接続管理

3. **GraphQL API 問題**
   - リゾルバーの実装
   - エラーハンドリング改善
   - レスポンス形式の統一

### 修正されたファイル

**Client Service:**

- `apps/client_service/mix.exs` - config_path 修正
- `apps/client_service/config/dev.exs` - ポート設定
- `apps/client_service/lib/client_service/endpoint.ex` - 最小限設定
- `apps/client_service/lib/client_service/application.ex` - 起動順序
- `apps/client_service/lib/client_service/router.ex` - GraphQL エンドポイント
- `apps/client_service/lib/client_service/error_json.ex` - エラーハンドリング
- `apps/client_service/lib/client_service/health_controller.ex` - ヘルスチェック
- `apps/client_service/lib/client_service/graphql/resolvers/*.ex` - リゾルバー修正

**Query Service:**

- `apps/query_service/lib/query_service/presentation/grpc/category_query_server.ex`
- `apps/query_service/lib/query_service/presentation/grpc/product_query_server.ex`

## 技術スタック

- **Language**: Elixir 1.18+
- **Web Framework**: Phoenix 1.7
- **GraphQL**: Absinthe
- **gRPC**: grpc-elixir
- **Database**: PostgreSQL + Ecto
- **Build Tool**: Mix
- **Serialization**: Protocol Buffers

## プロジェクト構造

```
elixir-cqrs/
├── apps/
│   ├── client_service/     # GraphQL API サーバー
│   ├── command_service/    # 書き込み専用 gRPC サーバー
│   ├── query_service/      # 読み取り専用 gRPC サーバー
│   └── shared/             # 共有ライブラリ
├── proto/                  # Protocol Buffers定義
└── README.md
```

## 🚀 マイクロサービス発展ロードマップ

### Phase 1: 統合開発・統合デプロイ（現在）

```
🎯 目標: 開発効率の最大化、迅速なプロトタイプ開発

✅ 完了した機能:
• Umbrella Project による統合管理
• 共有ライブラリ（Protocol Buffers）
• gRPC サービス間通信
• GraphQL API Gateway
• PostgreSQL データベース分離
• 自動テスト環境

🔧 開発方法:
• Monorepo 単一リポジトリ管理
• 統合的な依存関係管理
• 共通設定の一元化
• 統一されたCI/CD
```

### Phase 2: Docker 化・個別デプロイ（計画中）

```
🎯 目標: 独立デプロイ、スケーラビリティ向上

🔨 実装予定:
• Docker コンテナ化
• 個別サービスのリリース
• 負荷分散の実装
• 監視・ログ収集
• 環境別設定管理

🔧 技術スタック:
• Docker & Docker Compose
• Nginx (Load Balancer)
• Prometheus & Grafana
• ELK Stack (Logging)
• GitHub Actions (CI/CD)
```

### Phase 3: 本格マイクロサービス運用（将来）

```
🎯 目標: 企業レベルのスケーラビリティ、高可用性

🔮 実装予定:
• Kubernetes オーケストレーション
• サービスメッシュ（Istio）
• 分散トレーシング
• 自動スケーリング
• 障害回復（Circuit Breaker）
• API Gateway（Kong/Envoy）

🔧 技術スタック:
• Kubernetes (Container Orchestration)
• Istio (Service Mesh)
• Jaeger (Distributed Tracing)
• Prometheus (Metrics)
• Grafana (Dashboards)
• ArgoCD (GitOps)
```

## 📋 開発ロードマップ

### 短期目標（1-2 ヶ月）

- [x] **Docker 化の実装**

  - 各サービスの Dockerfile 作成
  - docker-compose.yml 設定
  - 開発環境のコンテナ化
  - CI/CD パイプライン構築

- [ ] **監視・ログ収集の実装**

  - Prometheus メトリクス収集
  - Grafana ダッシュボード作成
  - 構造化ログの実装
  - アラート設定

- [ ] **負荷テストの実施**

  - パフォーマンスベンチマーク
  - スケーラビリティテスト
  - ボトルネック特定
  - 最適化実施

- [ ] **API ドキュメントの充実**
  - GraphQL Playground 設定
  - OpenAPI 仕様書作成
  - コード例の追加
  - 開発者向けガイド

### 中期目標（3-6 ヶ月）

- [ ] **Kubernetes 対応**

  - マニフェストファイル作成
  - サービスディスカバリ設定
  - 設定管理（ConfigMap/Secret）
  - 永続化ストレージ設定

- [ ] **自動スケーリング**

  - HPA（Horizontal Pod Autoscaler）設定
  - メトリクスベーススケーリング
  - 負荷予測による事前スケーリング
  - コスト最適化

- [ ] **分散トレーシング**

  - Jaeger 統合
  - トレースコンテキスト伝播
  - パフォーマンス分析
  - 障害調査支援

- [ ] **障害回復機能**
  - Circuit Breaker 実装
  - Retry メカニズム
  - Fallback 戦略
  - 障害検知・通知

### 長期目標（6-12 ヶ月）

- [ ] **サービスメッシュ導入**

  - Istio デプロイ
  - トラフィック管理
  - セキュリティポリシー
  - 可観測性向上

- [ ] **企業レベルのスケーラビリティ**
  - マルチリージョン展開
  - グローバルロードバランシング
  - 災害復旧戦略
  - コンプライアンス対応

## 今後の課題

- [ ] 認証・認可の実装
- [ ] ログ・モニタリングの改善
- [ ] パフォーマンス最適化
- [ ] テストカバレッジの向上
- [ ] エラーレポート機能
- [ ] GraphQL Subscriptions 実装
- [ ] データベース接続プール調整

## 開発・デバッグ

### ログの確認

各サービスは起動時に詳細なログを出力します。問題が発生した場合は、ログを確認してください。

### ポート確認

```bash
netstat -an | grep -E "4000|50051|50052" | grep LISTEN
```

### プロセス確認

```bash
ps aux | grep mix
```

## ライセンス

MIT License
