# アーキテクチャ設計書

## 概要

このドキュメントは、Elixir CQRS Event-Driven Microservices プロジェクトの全体的なアーキテクチャ設計について説明します。本プロジェクトは、モダンなマイクロサービスアーキテクチャのベストプラクティスを実装し、スケーラブルで保守性の高いシステムを構築することを目的としています。

## アーキテクチャの原則

### 1. 関心の分離 (Separation of Concerns)

- **ドメイン層**: ビジネスロジックとルール
- **アプリケーション層**: ユースケースとワークフロー
- **インフラストラクチャ層**: 技術的実装の詳細
- **プレゼンテーション層**: UI/API インターフェース

### 2. 単一責任の原則 (Single Responsibility Principle)

各マイクロサービスは、明確に定義された 1 つの責任領域を持ちます：

- **Client Service**: API Gateway としての責任
- **Command Service**: 書き込み操作の処理
- **Query Service**: 読み取り操作の最適化

### 3. 依存性逆転の原則 (Dependency Inversion Principle)

- ドメイン層は外部依存を持たない
- インフラストラクチャ層がドメイン層のインターフェースを実装
- 依存性注入によるテスタビリティの向上

## システムアーキテクチャ

### 全体構成図

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend Applications                     │
│                    (Web, Mobile, Desktop, etc.)                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │ GraphQL over HTTP/WebSocket
                    ┌────────▼────────┐
                    │ Client Service  │
                    │  (API Gateway)  │
                    │    Port 4000    │
                    └───┬─────────┬───┘
                        │         │ gRPC (Protocol Buffers)
         ┌──────────────▼─┐   ┌───▼──────────────┐
         │Command Service │   │ Query Service    │
         │   (Write)      │   │   (Read)         │
         │  Port 50051    │   │  Port 50052      │
         └──────┬─────────┘   └────────┬─────────┘
                │                      │
     ┌──────────▼──────────┐  ┌────────▼────────┐
     │   Event Store       │  │  Read Models    │
     │   (PostgreSQL)      │  │  (PostgreSQL)   │
     │   Port 5432         │  │  Port 5433      │
     └────────┬────────────┘  └─────────────────┘
              │ Event Stream
     ┌────────▼────────────┐
     │ Projection Manager  │
     │ (Event Processor)   │
     └─────────────────────┘
```

### データフロー

#### 書き込みフロー (Command Flow)

```
1. Client → GraphQL Mutation
2. Client Service → Command via gRPC
3. Command Service → Validate & Process
4. Aggregate → Generate Domain Events
5. Event Store → Persist Events
6. Projection Manager → Update Read Models
7. Response → Client
```

#### 読み取りフロー (Query Flow)

```
1. Client → GraphQL Query
2. Client Service → Query via gRPC
3. Query Service → Fetch from Read Models
4. Response → Client (with caching)
```

## CQRS パターンの実装

### コマンドサイド

```elixir
# Command定義
defmodule CommandService.Domain.Commands.CreateProduct do
  defstruct [:name, :price, :category_id]
end

# CommandHandler
defmodule CommandService.Application.Handlers.ProductCommandHandler do
  def handle(%CreateProduct{} = command) do
    # 1. ビジネスルールの検証
    # 2. アグリゲートの操作
    # 3. イベントの生成
    # 4. イベントストアへの保存
  end
end

# CommandBus
defmodule CommandService.Application.CommandBus do
  def dispatch(command) do
    handler = resolve_handler(command)
    handler.handle(command)
  end
end
```

### クエリサイド

```elixir
# Query定義
defmodule QueryService.Domain.Queries.GetProductById do
  defstruct [:id]
end

# QueryHandler
defmodule QueryService.Application.Handlers.ProductQueryHandler do
  def handle(%GetProductById{id: id}) do
    # 読み取り最適化されたモデルから取得
    ProductReadModel.get(id)
  end
end

# QueryBus
defmodule QueryService.Application.QueryBus do
  def dispatch(query) do
    handler = resolve_handler(query)
    handler.handle(query)
  end
end
```

## イベントソーシング

### イベントストアの設計

```sql
-- イベントテーブル
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  aggregate_id UUID NOT NULL,
  aggregate_type VARCHAR(255) NOT NULL,
  event_type VARCHAR(255) NOT NULL,
  event_data JSONB NOT NULL,
  event_metadata JSONB,
  event_version INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  UNIQUE(aggregate_id, event_version)
);

-- スナップショットテーブル（将来の実装用）
CREATE TABLE snapshots (
  id BIGSERIAL PRIMARY KEY,
  aggregate_id UUID NOT NULL,
  aggregate_type VARCHAR(255) NOT NULL,
  snapshot_data JSONB NOT NULL,
  snapshot_version INTEGER NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### アグリゲートの実装

```elixir
defmodule Shared.Domain.Aggregate do
  @callback apply_event(state :: term(), event :: term()) :: term()

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Aggregate

      def load_from_events(events) do
        Enum.reduce(events, initial_state(), &apply_event(&2, &1))
      end

      def execute_command(state, command) do
        case handle_command(state, command) do
          {:ok, events} -> {:ok, events}
          {:error, reason} -> {:error, reason}
        end
      end
    end
  end
end
```

## マイクロサービス間通信

### gRPC の利用

Protocol Buffers による型安全な通信：

```protobuf
// command.proto
service CategoryCommand {
  rpc UpdateCategory(CategoryUpParam) returns (CategoryUpResult);
}

message CategoryUpParam {
  CRUD crud = 1;
  string id = 2;
  string name = 3;
}

message CategoryUpResult {
  Category category = 1;
  Error error = 2;
  google.protobuf.Timestamp timestamp = 3;
}
```

### 非同期メッセージング

将来的な実装として、イベント駆動の非同期通信：

```elixir
# イベントパブリッシャー
defmodule Shared.Infrastructure.EventPublisher do
  def publish(event) do
    # Kafka/RabbitMQ/Redis Streamsへの発行
  end
end

# イベントコンシューマー
defmodule Shared.Infrastructure.EventConsumer do
  def consume(topic, handler) do
    # イベントの受信と処理
  end
end
```

## レジリエンスパターン

### サーキットブレーカー

```elixir
defmodule Shared.Infrastructure.CircuitBreaker do
  @failure_threshold 5
  @timeout 60_000  # 60秒

  def call(service, fun) do
    case get_state(service) do
      :open ->
        {:error, :circuit_open}

      :half_open ->
        try_call(service, fun)

      :closed ->
        execute_with_monitoring(service, fun)
    end
  end
end
```

### リトライ機構

```elixir
defmodule Shared.Infrastructure.Retry do
  def with_retry(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    delay = Keyword.get(opts, :delay, 1000)

    do_retry(fun, max_attempts, delay, 1)
  end

  defp do_retry(fun, max_attempts, delay, attempt) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} when attempt < max_attempts ->
        Process.sleep(delay * attempt)  # エクスポネンシャルバックオフ
        do_retry(fun, max_attempts, delay, attempt + 1)

      {:error, reason} ->
        {:error, {:max_retries_exceeded, reason}}
    end
  end
end
```

## データ管理戦略

### イベントストア

- **PostgreSQL**: ACID 特性を活用した信頼性の高いイベント保存
- **イベントの順序保証**: aggregate_id と event_version による厳密な順序付け
- **イベントの不変性**: 一度保存されたイベントは変更されない

### 読み取りモデル

- **非正規化されたビュー**: クエリパフォーマンスの最適化
- **マテリアライズドビュー**: 複雑な集計の事前計算
- **キャッシング**: ETS と Redis による多層キャッシュ

### データ同期

```elixir
defmodule Shared.Infrastructure.ProjectionManager do
  def handle_event(event) do
    projections = find_projections_for(event)

    Enum.each(projections, fn projection ->
      Task.Supervisor.start_child(
        ProjectionTaskSupervisor,
        fn -> projection.handle(event) end
      )
    end)
  end
end
```

## セキュリティアーキテクチャ

### 認証・認可（将来実装）

```elixir
# JWT認証
defmodule ClientService.Middleware.Authentication do
  def call(conn, _opts) do
    with {:ok, token} <- extract_token(conn),
         {:ok, claims} <- verify_token(token) do
      assign(conn, :current_user, claims)
    else
      _ -> send_resp(conn, 401, "Unauthorized")
    end
  end
end

# 権限ベースアクセス制御
defmodule ClientService.Middleware.Authorization do
  def check_permission(user, resource, action) do
    # RBAC実装
  end
end
```

### データ保護

- **通信の暗号化**: TLS/SSL for gRPC and HTTP
- **データの暗号化**: 機密データの保存時暗号化
- **監査ログ**: すべての操作の記録

## スケーラビリティ戦略

### 水平スケーリング

```yaml
# Kubernetes Deployment例
apiVersion: apps/v1
kind: Deployment
metadata:
  name: query-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: query-service
  template:
    metadata:
      labels:
        app: query-service
    spec:
      containers:
        - name: query-service
          image: elixir-cqrs/query-service:latest
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
```

### データベースシャーディング

```elixir
# アグリゲートIDベースのシャーディング
defmodule Shared.Infrastructure.ShardRouter do
  @shards 4

  def route(aggregate_id) do
    hash = :erlang.phash2(aggregate_id, @shards)
    "shard_#{hash}"
  end
end
```

## 監視とオブザーバビリティ

### メトリクス収集

```elixir
defmodule Shared.Telemetry.Metrics do
  def metrics do
    [
      # システムメトリクス
      last_value("vm.memory.total"),
      last_value("vm.total_run_queue_lengths.total"),

      # ビジネスメトリクス
      counter("command.dispatched.count"),
      distribution("command.processing.duration"),
      counter("event.published.count"),

      # HTTPメトリクス
      counter("phoenix.endpoint.stop.duration"),
      distribution("phoenix.router_dispatch.stop.duration")
    ]
  end
end
```

### 分散トレーシング

```elixir
# OpenTelemetryスパン
defmodule CommandService.Tracing do
  require OpenTelemetry.Tracer, as: Tracer

  def trace_command(command_type, fun) do
    Tracer.with_span "command.#{command_type}" do
      Tracer.set_attributes([
        {"command.type", command_type},
        {"command.timestamp", DateTime.utc_now()}
      ])

      fun.()
    end
  end
end
```

## デプロイメントアーキテクチャ

### コンテナ化戦略

```dockerfile
# マルチステージビルド
FROM elixir:1.18-alpine AS build
WORKDIR /app
COPY . .
RUN mix deps.get --only prod
RUN MIX_ENV=prod mix release

FROM alpine:3.19
RUN apk add --no-cache openssl ncurses-libs
WORKDIR /app
COPY --from=build /app/_build/prod/rel/app ./
CMD ["bin/app", "start"]
```

### CI/CD パイプライン

```yaml
# GitHub Actions例
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and push Docker image
      - name: Deploy to Kubernetes
      - name: Run smoke tests
```

## 技術選定の理由

### Elixir/Erlang VM

- **高い並行性**: 軽量プロセスによる大規模な並行処理
- **耐障害性**: Let it crash フィロソフィーとスーパーバイザーツリー
- **ホットコードスワップ**: ダウンタイムなしのデプロイ

### PostgreSQL

- **ACID 準拠**: イベントストアの整合性保証
- **JSONB**: 柔軟なイベントデータの保存
- **パフォーマンス**: 高速な読み書き性能

### gRPC

- **型安全性**: Protocol Buffers による厳密な型定義
- **パフォーマンス**: HTTP/2 ベースの効率的な通信
- **多言語対応**: 将来的な他言語サービスとの統合

## 今後の拡張計画

### Phase 1（現在）

- ✅ CQRS 基本実装
- ✅ イベントソーシング
- ✅ サガパターン（部分的）
- ✅ 基本的な監視

### Phase 2（3 ヶ月）

- 認証・認可システム
- GraphQL Subscriptions
- イベントバージョニング
- スナップショット機能

### Phase 3（6 ヶ月）

- マルチテナント対応
- 高度なセキュリティ機能
- 機械学習による推薦システム
- グローバル分散デプロイメント

## まとめ

このアーキテクチャは、以下の特徴を持つシステムを実現します：

1. **高いスケーラビリティ**: 各コンポーネントが独立してスケール可能
2. **優れた保守性**: 明確な責任分離と疎結合
3. **強力な耐障害性**: Erlang VM とレジリエンスパターン
4. **柔軟な拡張性**: イベント駆動による新機能の追加容易性

継続的な改善と最新のベストプラクティスの採用により、長期的に持続可能なシステムを目指します。
