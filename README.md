# Elixir CQRS マイクロサービス（勉強用）

[![Elixir](https://img.shields.io/badge/elixir-1.14+-purple.svg)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/phoenix-1.7+-orange.svg)](https://phoenixframework.org/)
[![PostgreSQL](https://img.shields.io/badge/postgresql-13+-blue.svg)](https://postgresql.org/)
[![gRPC](https://img.shields.io/badge/grpc-0.10+-green.svg)](https://grpc.io/)
[![GraphQL](https://img.shields.io/badge/graphql-absinthe-ff69b4.svg)](https://hexdocs.pm/absinthe/)

## 🎯 概要

CQRS（Command Query Responsibility Segregation）パターンを Elixir で実装したマイクロサービスプロジェクトです。関数型プログラミング、Domain-Driven Design（DDD）、Clean Architecture のベストプラクティスを適用し、**Umbrella Project + Monorepo** 構成で管理しています。

個人の勉強用リポジトリです。

## 🏗️ アーキテクチャ

### システム構成図

```
┌─────────────────────────────────────────────────────────────────┐
│                        External Clients                         │
│           Web Browser • Mobile App • External API               │
└─────────────────────────┬───────────────────────────────────────┘
                          │ GraphQL API
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Client Service :4000                         │
│                    GraphQL API Gateway                          │
└─────────────┬─────────────────────────────────────┬─────────────┘
              │ gRPC                                │ gRPC
              ▼                                     ▼
┌─────────────────────────────┐       ┌─────────────────────────────┐
│   Command Service :50051    │       │   Query Service :50052      │
│      (Write Operations)     │       │     (Read Operations)       │
│                             │       │                             │
│ • Create/Update/Delete      │       │ • Search/Filter/Aggregate   │
│ • Business Logic            │       │ • Reports/Analytics         │
│ • Domain Events             │       │ • Read-only Models          │
└─────────────┬───────────────┘       └─────────────┬───────────────┘
              │                                     │
              ▼                                     ▼
┌─────────────────────────────┐       ┌─────────────────────────────┐
│   PostgreSQL (Command)      │       │   PostgreSQL (Query)        │
│   command_service_db        │       │   query_service_db          │
└─────────────────────────────┘       └─────────────────────────────┘
```

### Umbrella Project 構成

```
elixir-cqrs/                         # 🗂️ Monorepo ルート
├── mix.exs                          # Umbrella project設定
├── config/                          # 共通設定
│   ├── config.exs                   # 基本設定
│   ├── dev.exs                      # 開発環境
│   ├── prod.exs                     # 本番環境
│   └── test.exs                     # テスト環境
├── apps/                            # 🚀 各マイクロサービス
│   ├── shared/                      # 📦 共有ライブラリ
│   │   ├── lib/proto/               # Protocol Buffers（統一管理）
│   │   └── mix.exs                  # gRPC、Decimal依存関係
│   ├── command_service/             # ✏️ コマンドサービス
│   │   ├── lib/
│   │   │   ├── domain/              # ドメインレイヤー
│   │   │   │   ├── value_objects/   # CategoryId、ProductPrice等
│   │   │   │   ├── entities/        # Category、Product
│   │   │   │   └── repositories/    # インターフェース
│   │   │   ├── application/         # アプリケーションレイヤー
│   │   │   │   └── services/        # CategoryService
│   │   │   └── infrastructure/      # インフラストラクチャレイヤー
│   │   │       ├── database/        # Connection、Schemas
│   │   │       └── repositories/    # 実装
│   │   ├── priv/repo/migrations/    # マイグレーション
│   │   └── config/                  # 設定ファイル
│   ├── query_service/               # 🔍 クエリサービス
│   │   ├── lib/domain/models/       # 読み取り専用モデル
│   │   ├── lib/domain/repositories/ # インターフェース
│   │   ├── lib/infrastructure/      # データベース接続
│   │   └── config/                  # 設定ファイル
│   └── client_service/              # 🌐 クライアントサービス
│       ├── lib/graphql/             # GraphQL API
│       └── lib/infrastructure/      # gRPC接続
├── scripts/generate_proto.sh        # 統一protoスクリプト
└── DEVELOPMENT_GUIDE.md             # 開発ガイドライン
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

## 📊 サービス仕様

### Command Service（書き込み専用）

```elixir
# 責務: データの作成・更新・削除
# ポート: 50051
# データベース: PostgreSQL（書き込み用）
# プロトコル: gRPC

# アーキテクチャ:
Presentation Layer (gRPC Server)
      ↓
Application Layer (Service)
      ↓
Domain Layer (Entity, Value Object)
      ↓
Infrastructure Layer (Repository, Database)
```

### Query Service（読み取り専用）

```elixir
# 責務: データの検索・集計・統計
# ポート: 50052
# データベース: PostgreSQL（読み取り用）
# プロトコル: gRPC

# 特徴:
• 高度な検索機能（部分一致、価格範囲、ページネーション）
• 統計情報の提供
• 読み取り専用データモデル
• パフォーマンス最適化
```

### Client Service（API Gateway）

```elixir
# 責務: GraphQL API 提供、gRPC クライアント
# ポート: 4000
# プロトコル: GraphQL over HTTP/WebSocket
# 特徴: リアルタイム通信（Subscription）

# API 例:
query {
  products(categoryId: "1") {
    id
    name
    price
    category {
      name
    }
  }
}
```

## 🛠️ 技術スタック

### Core Technologies

| 技術         | バージョン | 用途               |
| ------------ | ---------- | ------------------ |
| **Elixir**   | 1.14+      | 主要言語           |
| **Phoenix**  | 1.7+       | Web フレームワーク |
| **Ecto**     | 3.0+       | データベース ORM   |
| **Absinthe** | 1.7+       | GraphQL            |

### Communication

| 技術                 | バージョン | 用途             |
| -------------------- | ---------- | ---------------- |
| **gRPC**             | 0.10+      | サービス間通信   |
| **Protocol Buffers** | 0.14+      | データ形式       |
| **WebSocket**        | Built-in   | リアルタイム通信 |

### Database

| 技術           | バージョン | 用途                  |
| -------------- | ---------- | --------------------- |
| **PostgreSQL** | 13+        | 主要データベース      |
| **Postgrex**   | 0.20+      | PostgreSQL ドライバー |

### Development & Testing

| 技術           | バージョン | 用途                   |
| -------------- | ---------- | ---------------------- |
| **Credo**      | 1.6+       | 静的コード解析         |
| **ExDoc**      | 0.27+      | ドキュメント生成       |
| **Dialyxir**   | 1.0+       | 型チェック             |
| **Mox**        | 1.0+       | モック                 |
| **StreamData** | 0.6+       | プロパティベーステスト |

## 🎯 Git 管理戦略

### Monorepo 構成

```bash
# 推奨：単一リポジトリでの管理
git init                           # ルートディレクトリで初期化
git remote add origin <repo-url>   # リモートリポジトリ設定

# 利点：
✅ Umbrella Project との統合性
✅ 共有ライブラリの統一管理
✅ 依存関係の見通しの良さ
✅ 統一されたCI/CD
✅ Protocol Buffers等の共有コンポーネント管理
```

### ブランチ戦略

```
main                               # 本番用（安定版）
├── develop                        # 開発統合
├── feature/add-product-search     # 機能開発
├── feature/add-monitoring         # 機能開発
├── hotfix/fix-critical-bug        # 緊急修正
└── release/v1.0.0                 # リリース準備
```

### コミット規約

```
feat: 新機能追加
fix: バグ修正
docs: ドキュメント更新
style: コードスタイル修正
refactor: リファクタリング
test: テスト追加・修正
chore: ビルド・設定・依存関係
```

## 🚀 セットアップ

### 前提条件

```bash
# 必要なソフトウェア
elixir --version        # 1.14+
mix --version          # 1.14+
psql --version         # 13+
git --version          # 2.x+
```

### 1. プロジェクト取得

```bash
# リポジトリクローン
git clone https://github.com/your-username/elixir-cqrs.git
cd elixir-cqrs

# 依存関係インストール
mix deps.get
```

### 2. データベースセットアップ

```bash
# PostgreSQL サービス起動
brew services start postgresql
# または
systemctl start postgresql

# データベース作成とマイグレーション
mix ecto.setup

# 個別実行の場合
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

### 3. Protocol Buffers 生成

```bash
# 共有ライブラリのproto生成
./scripts/generate_proto.sh

# 確認
ls apps/shared/lib/proto/
```

## 💻 開発

### 開発サーバー起動

```bash
# 🎯 推奨：全サービス並行起動
mix start.all

# 個別起動
mix cmd --app command_service mix run --no-halt    # Terminal 1
mix cmd --app query_service mix run --no-halt      # Terminal 2
mix cmd --app client_service mix phx.server        # Terminal 3
```

### 開発ワークフロー

```bash
# 1. 新機能開発
git checkout -b feature/new-awesome-feature

# 2. Protocol Buffers 更新（必要に応じて）
vim proto/models.proto
./scripts/generate_proto.sh

# 3. サービス開発
cd apps/command_service
# ... 開発作業 ...

# 4. テスト実行
mix test

# 5. コード品質チェック
mix format
mix credo --strict
mix dialyzer

# 6. コミット
git add .
git commit -m "feat: Add awesome new feature"
git push origin feature/new-awesome-feature
```

### テスト実行

```bash
# 全アプリのテスト
mix test

# 特定のアプリのテスト
mix cmd --app command_service mix test
mix cmd --app query_service mix test
mix cmd --app client_service mix test

# カバレッジ付きテスト
mix test --cover
```

### コード品質チェック

```bash
# 一括実行
mix quality

# 個別実行
mix format          # コードフォーマット
mix credo --strict  # 静的解析
mix dialyzer        # 型チェック
mix docs            # ドキュメント生成
```

## 📡 API 仕様

### GraphQL API (Client Service)

```graphql
# 🔍 クエリ例
query GetProducts {
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

# 🔍 検索例
query SearchProducts {
  searchProducts(
    name: "laptop"
    priceRange: { min: 1000, max: 2000 }
    pagination: { page: 1, limit: 10 }
  ) {
    products {
      id
      name
      price
    }
    totalCount
  }
}

# ✏️ ミューテーション例
mutation CreateProduct {
  createProduct(
    input: { name: "New Product", price: 999.99, categoryId: "1" }
  ) {
    id
    name
    price
  }
}

# 🔔 サブスクリプション例
subscription ProductUpdates {
  productUpdated {
    id
    name
    price
    updatedAt
  }
}
```

### gRPC API (Internal)

```protobuf
// Command Service
service CategoryCommand {
  rpc CreateCategory(CreateCategoryRequest) returns (CreateCategoryResponse);
  rpc UpdateCategory(UpdateCategoryRequest) returns (UpdateCategoryResponse);
  rpc DeleteCategory(DeleteCategoryRequest) returns (DeleteCategoryResponse);
}

// Query Service
service CategoryQuery {
  rpc GetCategory(GetCategoryRequest) returns (GetCategoryResponse);
  rpc ListCategories(ListCategoriesRequest) returns (ListCategoriesResponse);
  rpc SearchCategories(SearchCategoriesRequest) returns (SearchCategoriesResponse);
}
```

## 🚀 デプロイ

### Phase 1: 統合デプロイ（現在）

```bash
# 本番ビルド
MIX_ENV=prod mix release

# 起動
_build/prod/rel/elixir_cqrs/bin/elixir_cqrs start
```

### Phase 2: Docker デプロイ（計画中）

```dockerfile
# Dockerfile example
FROM elixir:1.14-alpine

# ... build steps ...

EXPOSE 4000 50051 50052
CMD ["mix", "phx.server"]
```

```yaml
# docker-compose.yml
version: "3.8"
services:
  command-service:
    build: ./apps/command_service
    ports:
      - "50051:50051"
    depends_on:
      - postgres-command

  query-service:
    build: ./apps/query_service
    ports:
      - "50052:50052"
    depends_on:
      - postgres-query

  client-service:
    build: ./apps/client_service
    ports:
      - "4000:4000"
    depends_on:
      - command-service
      - query-service
```

### Phase 3: Kubernetes デプロイ（将来）

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: client-service
  template:
    metadata:
      labels:
        app: client-service
    spec:
      containers:
        - name: client-service
          image: elixir-cqrs/client-service:latest
          ports:
            - containerPort: 4000
```

## 📊 監視・運用

### 健全性チェック

```bash
# サービス状態確認
curl http://localhost:4000/health

# GraphQL エンドポイント確認
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { types { name } } }"}'
```

### ログ管理

```elixir
# 構造化ログ
Logger.info("Product created", %{
  product_id: product.id,
  user_id: user.id,
  action: "create_product"
})
```

### メトリクス（将来実装）

```elixir
# Prometheus メトリクス例
:telemetry.execute([:elixir_cqrs, :product, :created], %{count: 1}, %{
  category_id: category.id
})
```

## 🤝 開発ガイドライン

### コーディング規約

```elixir
# 🇯🇵 日本語使用箇所
@doc """
カテゴリを作成します。

## 例
    iex> CategoryService.create_category(%{name: "電子機器"})
    {:ok, %Category{}}
"""

# 🇺🇸 英語使用箇所
def create_category(params) do
  # Private function comments in Japanese
  # カテゴリの妥当性を検証
  with {:ok, category} <- validate_category(params) do
    Logger.info("Category created successfully", %{category_id: category.id})
    {:ok, category}
  else
    {:error, reason} ->
      Logger.error("Failed to create category", %{reason: reason})
      {:error, "Category creation failed"}
  end
end
```

### テスト戦略

```elixir
# テストケース名は英語
describe "create_category/1" do
  test "creates category with valid params" do
    # テスト実装
  end

  test "returns error with invalid params" do
    # テスト実装
  end
end
```

## 🎯 次のステップ

### 短期目標（1-2 ヶ月）

- [ ] Docker 化の実装
- [ ] 監視・ログ収集の実装
- [ ] 負荷テストの実施
- [ ] API ドキュメントの充実

### 中期目標（3-6 ヶ月）

- [ ] Kubernetes 対応
- [ ] 自動スケーリング
- [ ] 分散トレーシング
- [ ] 障害回復機能

### 長期目標（6-12 ヶ月）

- [ ] サービスメッシュ導入
  <!-- - [ ] 多地域展開 -->
  <!-- - [ ] ML/AI 機能統合 -->
- [ ] 企業レベルのスケーラビリティ

## 📝 ライセンス

なし

## 🔗 関連リンク

- [Elixir 公式ドキュメント](https://elixir-lang.org/docs.html)
- [Phoenix Framework](https://phoenixframework.org/)
- [Absinthe GraphQL](https://absinthe-graphql.org/)
- [gRPC Elixir](https://hex.pm/packages/grpc)
- [PostgreSQL](https://www.postgresql.org/)
