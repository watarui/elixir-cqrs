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

### 新機能（CQRS + イベントソーシング）

- [x] **イベントソーシング基盤**
  - イベント型定義（BaseEvent、ProductEvents、CategoryEvents）
  - イベントストア（In-Memory実装）
  - アグリゲート基底クラス
  - イベントソース対応アグリゲート（ProductAggregate、CategoryAggregate）

- [x] **コマンド側（書き込み）**
  - コマンド定義（CreateProduct、UpdateProduct、DeleteProduct等）
  - コマンドハンドラー
  - コマンドバス（メディエーターパターン）
  - コマンドバリデーション

- [x] **クエリ側（読み取り）**
  - クエリ定義（GetProduct、ListProducts、SearchProducts等）
  - クエリハンドラー
  - クエリバス
  - 並列クエリ実行サポート

- [x] **統一インターフェース**
  - CQRSファサード
  - コマンド/クエリの統一実行API
  - 非同期コマンド実行
  - トランザクションサポート（簡易版）

## アーキテクチャ

### 基本構成
```
[Client Service:4000]  ←→  HTTP/GraphQL  ←→  [Web Client]
         ↓
      gRPC calls
         ↓
[Command Service:50051] ←→ [Database]
[Query Service:50052]  ←→ [Database]
```

### CQRS + イベントソーシング アーキテクチャ
```
┌─────────────────────────────────────────────────────────────┐
│                     Client Service (GraphQL)                 │
│                         CQRS Facade                          │
└────────────────┬─────────────────────┬──────────────────────┘
                 │                     │
        ┌────────▼────────┐   ┌───────▼───────┐
        │  Command Bus    │   │  Query Bus    │
        └────────┬────────┘   └───────┬───────┘
                 │                     │
        ┌────────▼────────┐   ┌───────▼───────┐
        │Command Handlers │   │Query Handlers │
        └────────┬────────┘   └───────┬───────┘
                 │                     │
        ┌────────▼────────┐   ┌───────▼───────┐
        │   Aggregates    │   │  Read Models  │
        │ (Event Sourced) │   │  (Projections)│
        └────────┬────────┘   └───────┬───────┘
                 │                     │
        ┌────────▼────────────────────▼───────┐
        │           Event Store               │
        │      (In-Memory / PostgreSQL)       │
        └─────────────────────────────────────┘
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

#### 2. カテゴリ作成（Mutation）

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createCategory(input: {name: \"Electronics\"}) { id name } }"}'
```

#### 3. 商品作成（Mutation）

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createProduct(input: {name: \"Laptop\", price: 1500.0, categoryId: \"<category-id>\"}) { id name price } }"}'
```

#### 4. カテゴリ一覧取得

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ categories { id name } }"}'
```

#### 5. 商品一覧取得（カテゴリ情報含む）

```bash
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ products { id name price category { id name } } }"}'
```

#### 6. イベントソーシングの動作確認

コマンドを実行後、3秒程度待ってからクエリを実行してください。
ProjectionManagerがイベントを読み取ってRead Modelを更新します。

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
- **Architecture Patterns**:
  - CQRS (Command Query Responsibility Segregation)
  - Event Sourcing
  - Domain-Driven Design (DDD)
  - Mediator Pattern (Command/Query Bus)
  - Repository Pattern

## プロジェクト構造

```
elixir-cqrs/
├── apps/
│   ├── client_service/     # GraphQL API サーバー
│   │   ├── application/    # CQRSファサード
│   │   └── graphql/        # GraphQLスキーマ・リゾルバー
│   ├── command_service/    # 書き込み専用 gRPC サーバー
│   │   ├── domain/         # ドメイン層
│   │   │   ├── aggregates/ # イベントソーシング対応アグリゲート
│   │   │   ├── entities/   # エンティティ
│   │   │   └── value_objects/ # 値オブジェクト
│   │   ├── application/    # アプリケーション層
│   │   │   ├── commands/   # コマンド定義
│   │   │   ├── handlers/   # コマンドハンドラー
│   │   │   └── command_bus.ex # コマンドバス（メディエーター）
│   │   └── infrastructure/ # インフラ層
│   ├── query_service/      # 読み取り専用 gRPC サーバー
│   │   ├── domain/         # ドメイン層（読み取りモデル）
│   │   ├── application/    # アプリケーション層
│   │   │   ├── queries/    # クエリ定義
│   │   │   ├── handlers/   # クエリハンドラー
│   │   │   └── query_bus.ex # クエリバス
│   │   └── infrastructure/ # インフラ層（キャッシュ含む）
│   └── shared/             # 共有ライブラリ
│       ├── domain/         # 共有ドメイン層
│       │   ├── events/     # イベント定義
│       │   └── aggregate/  # アグリゲート基底クラス
│       ├── infrastructure/ # 共有インフラ層
│       │   └── event_store/ # イベントストア実装
│       └── application/    # 共有アプリケーション層
│           └── cqrs_facade.ex # CQRS統一インターフェース
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

## リファクタリング推奨事項

### 1. コアドメインロジックの改善

- [x] **Product 更新ロジックのリファクタリング**

  - やっつけ実装を改善済み（`ProductService.apply_updates`）
  - データ駆動型アプローチで拡張性を向上

- [x] **エンティティの`update`メソッド統一**
  - 現在: 個別フィールドごとの更新メソッド（`update_name`, `update_price`等）→ 完了
  - 推奨: 統一された`update/2`メソッドで複数フィールドを一度に更新 → 実装済み
  ```elixir
  def update(entity, params) do
    # バリデーションとアトミックな更新
  end
  ```

### 2. 型安全性とインターフェースの強化

- [x] **型定義の徹底**

  - すべての関数に`@spec`を必須化（主要モジュールに追加完了）
    - GraphQL リゾルバー（ProductResolver、CategoryResolver）
    - gRPC サーバー（一部実装）
    - 値オブジェクト（実装済み）
  - カスタム型（`@type`）の積極的活用（実装済み）
  - Dialyzer の警告をゼロに（今後の課題）

- [x] **ビヘイビアの活用**

  - リポジトリインターフェースの定義（完了）
  - サービス層のコントラクト明確化（完了）
  - CommandService.Domain.Repositories.ProductRepository（実装済み）
  - CommandService.Domain.Repositories.CategoryRepository（実装済み）
  - QueryService.Domain.Repositories.ProductRepository（実装済み）
  - QueryService.Domain.Repositories.CategoryRepository（実装済み）

- [x] **値オブジェクトの型安全性向上**
  - opaque タイプの使用検討（実装済み）
    - ProductId、CategoryId、ProductName、CategoryName、ProductPrice
  - ファクトリー関数でのみ生成可能に（new/1 関数で実装済み）

### 3. エラーハンドリングの統一

- [x] **エラー型の標準化**

  - 統一されたエラー構造体の定義（AppError 実装済み）
  - エラーカテゴリの明確化（ドメインエラー、インフラエラー等）

  ```elixir
  defmodule AppError do
    @type t :: %__MODULE__{
      type: atom(),
      message: String.t(),
      details: map()
    }
  end
  ```

### 4. CQRS パターンの完全実装

- [x] **イベントソーシングの導入**

  - イベント基盤の実装（BaseEvent、ドメインイベント定義）
  - イベントストアの実装（EventStore、InMemoryAdapter）
  - アグリゲート基底クラス（Aggregate.Base）
  - ProductAggregate、CategoryAggregateの実装

- [x] **コマンド/クエリの明確な分離**
  - コマンドハンドラーの抽出（ProductCommandHandler、CategoryCommandHandler）
  - クエリハンドラーの抽出（ProductQueryHandler、CategoryQueryHandler）
  - メディエーターパターンの実装（CommandBus、QueryBus）
  - 統一インターフェース（CQRSFacade）

### 5. インフラストラクチャの改善

- [x] **gRPC エラーハンドリング**

  - カスタムエラーステータスの定義（GrpcErrorConverter 実装済み）
  - AppError から Proto.Error への統一変換（完了）
  - gRPC ステータスコードのマッピング（完了）
  - リトライ戦略の実装（今後の課題）
  - サーキットブレーカーの追加（今後の課題）

- [ ] **データベース層の抽象化**
  - リポジトリパターンの完全実装
  - Unit of Work パターンの検討
  - トランザクション管理の改善

### 6. テスタビリティの向上

- [x] **依存性注入の改善**

  - ハードコードされた依存を排除（完了）
  - モックしやすい設計に（完了）

  ```elixir
  # 現在
  @repo ProductRepo

  # 推奨
  def create_product(params, repo \\ ProductRepo) do
    # テスト時にモックリポジトリを注入可能
  end
  ```

- [ ] **ピュアな関数の増加**
  - 副作用を持つ関数の分離
  - ビジネスロジックのテスト容易性向上

### 7. パフォーマンス最適化

- [ ] **N+1 クエリの解決**

  - DataLoader の導入（GraphQL）
  - プリロード戦略の最適化

- [x] **キャッシング戦略**
  - クエリサービスでのキャッシュ実装（完了）
  - ETS を使用したインメモリキャッシュ（完了）
  - TTL ベースの自動期限切れ処理（完了）
  - CategoryRepository と ProductRepository にキャッシング適用（完了）

## コーディング規約

### 言語

- コードコメントは日本語
- コードドキュメントは日本語
- ログ出力は英語
- エラー文言は英語
- テストケース名は英語

### 型とインターフェースの重視

1. **すべての公開関数に`@spec`を記述する**

   ```elixir
   @spec create_product(params :: map()) :: {:ok, Product.t()} | {:error, String.t()}
   def create_product(params) do
     # 実装
   end
   ```

2. **カスタム型の積極的な定義**

   ```elixir
   @type product_id :: String.t()
   @type price :: Decimal.t()
   @type result(success) :: {:ok, success} | {:error, String.t()}
   ```

3. **ビヘイビアを使用してインターフェースを明確化**

   ```elixir
   defmodule CommandHandler do
     @callback handle(command :: struct()) :: {:ok, any()} | {:error, any()}
   end
   ```

4. **Dialyzer を活用した型チェック**

   - すべての Dialyzer 警告を解決する
   - CI/CD パイプラインで Dialyzer を実行

5. **値オブジェクトによる型安全性の確保**

   - プリミティブ型の直接使用を避ける
   - ドメイン固有の型を定義して使用

6. **エラー型の明確な定義**
   - タプルではなく構造体でエラーを表現
   - エラーの種類と詳細を型で表現

## 今後の課題

### 短期（優先度高）
- [ ] イベントストアのPostgreSQL実装
- [ ] プロジェクション（読み取りモデル）の自動更新
- [ ] サガパターンの実装（分散トランザクション）
- [ ] gRPCリトライ戦略とサーキットブレーカー
- [ ] Unit of Workパターンの実装

### 中期
- [ ] 認証・認可の実装
- [ ] GraphQL Subscriptions（リアルタイム更新）
- [ ] DataLoader実装（N+1問題解決）
- [ ] イベントの永続化とリプレイ機能
- [ ] スナップショット機能

### 長期
- [ ] ログ・モニタリングの改善
- [ ] パフォーマンス最適化
- [ ] テストカバレッジの向上
- [ ] エラーレポート機能
- [ ] データベース接続プール調整
- [ ] イベントバージョニング戦略

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
