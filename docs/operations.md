# 運用マニュアル

## 概要

このドキュメントは、Elixir CQRS Event-Driven Microservices システムの運用に必要な手順と情報をまとめたものです。開発環境から本番環境まで、システムの安定稼働を維持するためのガイドラインを提供します。

## 環境構成

### 開発環境

```yaml
Services:
  - Client Service: localhost:4000
  - Command Service: localhost:50051
  - Query Service: localhost:50052
  - PostgreSQL (Event Store): localhost:5432
  - PostgreSQL (Query DB): localhost:5433
  - PostgreSQL (Command DB): localhost:5434
```

### ステージング環境

```yaml
Services:
  - Client Service: staging.example.com
  - Command Service: command.staging.example.com:50051
  - Query Service: query.staging.example.com:50052
  - PostgreSQL: Managed Database Service
```

### 本番環境

```yaml
Services:
  - Client Service: api.example.com (Load Balanced)
  - Command Service: Internal Network Only
  - Query Service: Internal Network Only
  - PostgreSQL: High Availability Cluster
```

## デプロイメント

### Docker Compose を使用したデプロイ

#### 1. 環境変数の設定

```bash
# .env.production
DATABASE_URL=postgres://user:pass@db:5432/prod_db
SECRET_KEY_BASE=your-secret-key-base
PHX_HOST=api.example.com
POOL_SIZE=10
```

#### 2. イメージのビルド

```bash
# すべてのサービスをビルド
docker compose build

# 特定のサービスのみビルド
docker compose build client_service
```

#### 3. サービスの起動

```bash
# すべてのサービスを起動
docker compose up -d

# スケールアウト
docker compose up -d --scale query_service=3
```

### Kubernetes へのデプロイ

#### 1. ConfigMap の作成

```bash
kubectl create configmap app-config \
  --from-file=config/prod.exs \
  --namespace=production
```

#### 2. Secret の作成

```bash
kubectl create secret generic app-secrets \
  --from-literal=database-url='postgres://...' \
  --from-literal=secret-key-base='...' \
  --namespace=production
```

#### 3. デプロイメントの適用

```bash
# デプロイメント
kubectl apply -f k8s/deployment.yaml

# サービス
kubectl apply -f k8s/service.yaml

# Ingress
kubectl apply -f k8s/ingress.yaml
```

#### 4. ローリングアップデート

```bash
# イメージの更新
kubectl set image deployment/client-service \
  client-service=elixir-cqrs/client-service:v1.2.0 \
  --namespace=production

# デプロイメントステータスの確認
kubectl rollout status deployment/client-service
```

## 監視

### ヘルスチェック

#### エンドポイント

```bash
# Client Service
curl http://localhost:4000/health

# Command Service (gRPC Health Check)
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check

# Query Service (gRPC Health Check)
grpcurl -plaintext localhost:50052 grpc.health.v1.Health/Check
```

#### 期待されるレスポンス

```json
{
  "status": "ok",
  "version": "1.0.0",
  "services": {
    "database": "connected",
    "cache": "connected",
    "grpc": "serving"
  }
}
```

### メトリクス監視

#### Prometheus エンドポイント

```bash
# 各サービスのメトリクス
curl http://localhost:4000/metrics      # Client Service
curl http://localhost:9569/metrics      # Command Service
curl http://localhost:9570/metrics      # Query Service
```

#### 重要なメトリクス

```yaml
Critical Metrics:
  - phoenix_endpoint_stop_duration: API応答時間
  - command_processing_duration: コマンド処理時間
  - event_store_append_duration: イベント保存時間
  - saga_completion_rate: サガ完了率
  - database_connection_pool_size: DB接続プール

Alerts:
  - API Response Time > 500ms
  - Command Processing Time > 1s
  - Error Rate > 1%
  - Database Connection Pool > 80%
```

### ログ管理

#### ログレベルの設定

```elixir
# config/prod.exs
config :logger, level: :info
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id]
```

#### 構造化ログの検索

```bash
# エラーログの検索
docker compose logs -f client_service | grep "level=error"

# 特定のリクエストIDの追跡
docker compose logs -f | grep "request_id=abc123"

# サガの実行ログ
docker compose logs -f command_service | grep "saga_id"
```

### 分散トレーシング

#### Jaeger でのトレース確認

1. Jaeger UI にアクセス: http://localhost:16686
2. サービスを選択
3. オペレーションを選択
4. トレースを検索

#### トレースの分析ポイント

- レイテンシーのボトルネック
- エラーの発生箇所
- サービス間の依存関係
- リトライの発生

## バックアップとリストア

### データベースバックアップ

#### 自動バックアップスクリプト

```bash
#!/bin/bash
# backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"

# Event Store
pg_dump $EVENT_STORE_URL > "$BACKUP_DIR/event_store_$DATE.sql"

# Query Database
pg_dump $QUERY_DB_URL > "$BACKUP_DIR/query_db_$DATE.sql"

# S3へアップロード
aws s3 cp "$BACKUP_DIR/event_store_$DATE.sql" s3://backup-bucket/
aws s3 cp "$BACKUP_DIR/query_db_$DATE.sql" s3://backup-bucket/

# 古いバックアップの削除
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
```

#### リストア手順

```bash
# 1. サービスの停止
docker compose stop

# 2. データベースのリストア
psql $EVENT_STORE_URL < event_store_backup.sql
psql $QUERY_DB_URL < query_db_backup.sql

# 3. プロジェクションの再構築（必要な場合）
docker compose run --rm command_service mix rebuild_projections

# 4. サービスの再開
docker compose start
```

### イベントストアの整合性チェック

```elixir
# lib/tasks/event_store_check.ex
defmodule Mix.Tasks.EventStore.Check do
  use Mix.Task

  def run(_) do
    # アプリケーションの起動
    Mix.Task.run("app.start")

    # イベントの整合性チェック
    check_event_continuity()
    check_aggregate_versions()
    check_orphaned_events()
  end
end
```

## スケーリング

### 水平スケーリング

#### Query Service のスケールアウト

```bash
# Docker Compose
docker compose up -d --scale query_service=5

# Kubernetes
kubectl scale deployment query-service --replicas=5
```

#### ロードバランサー設定

```nginx
upstream query_services {
    least_conn;
    server query_service_1:50052;
    server query_service_2:50052;
    server query_service_3:50052;
}
```

### 垂直スケーリング

#### リソースの調整

```yaml
# docker-compose.yml
services:
  command_service:
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 4G
        reservations:
          cpus: "1"
          memory: 2G
```

### データベースのスケーリング

#### 読み取りレプリカの追加

```elixir
# config/prod.exs
config :query_service, QueryService.Repo,
  read_replicas: [
    [url: System.get_env("DATABASE_REPLICA_1_URL")],
    [url: System.get_env("DATABASE_REPLICA_2_URL")]
  ]
```

## トラブルシューティング

### 一般的な問題と解決策

#### 1. メモリリーク

**症状**: メモリ使用量が継続的に増加

**診断**:

```elixir
# Erlang shellでの確認
:erlang.memory()
:recon.proc_count(:memory, 10)
```

**解決策**:

- プロセスのメッセージキューを確認
- 大きな ETS テーブルの確認
- バイナリリファレンスのリーク確認

#### 2. データベース接続エラー

**症状**: `Ecto.NoResultsError` or `DBConnection.ConnectionError`

**診断**:

```bash
# 接続プールの状態確認
echo "SELECT count(*) FROM pg_stat_activity;" | psql $DATABASE_URL
```

**解決策**:

```elixir
# プールサイズの調整
config :my_app, MyApp.Repo,
  pool_size: 20,
  queue_target: 5000,
  queue_interval: 1000
```

#### 3. gRPC 通信エラー

**症状**: `GRPC.RPCError` with status 14 (UNAVAILABLE)

**診断**:

```bash
# サービスの疎通確認
grpcurl -plaintext localhost:50051 list
```

**解決策**:

- サービスの再起動
- ネットワーク設定の確認
- タイムアウト値の調整

### パフォーマンスチューニング

#### 1. Erlang VM の最適化

```bash
# 起動オプション
ERL_FLAGS="+P 5000000 +Q 1000000 +K true +A 128"
```

#### 2. データベースインデックス

```sql
-- 頻繁にクエリされるカラムにインデックス
CREATE INDEX CONCURRENTLY idx_events_created_at
ON events(created_at)
WHERE created_at > NOW() - INTERVAL '30 days';

-- 複合インデックス
CREATE INDEX CONCURRENTLY idx_products_category_price
ON products(category_id, price);
```

#### 3. キャッシュの活用

```elixir
# ETS キャッシュの設定
defmodule Cache do
  def start_link do
    :ets.new(:cache, [:set, :public, :named_table])
  end

  def get(key), do: :ets.lookup(:cache, key)
  def put(key, value, ttl), do: :ets.insert(:cache, {key, value, expiry(ttl)})
end
```

## セキュリティ

### 定期的なセキュリティタスク

#### 1. 依存関係の更新

```bash
# セキュリティ脆弱性のチェック
mix deps.audit

# 依存関係の更新
mix deps.update --all
```

#### 2. シークレットのローテーション

```bash
# データベースパスワードの変更
ALTER USER app_user WITH PASSWORD 'new_secure_password';

# アプリケーションシークレットの更新
mix phx.gen.secret
```

#### 3. SSL 証明書の更新

```bash
# Let's Encryptの自動更新
certbot renew --dry-run
```

### アクセス制御

#### IP ホワイトリスト

```nginx
# nginx設定
location /admin {
    allow 10.0.0.0/8;
    allow 192.168.0.0/16;
    deny all;
}
```

#### レート制限

```elixir
# Plug設定
plug Hammer.Plug, [
  rate_limit: {"minute", 60},
  by: :ip
]
```

## 災害復旧

### RTO/RPO 目標

- **RTO (Recovery Time Objective)**: 4 時間
- **RPO (Recovery Point Objective)**: 1 時間

### 復旧手順

#### 1. システム全体のダウン

```bash
# 1. 状況確認
./scripts/health_check_all.sh

# 2. バックアップからの復旧
./scripts/disaster_recovery.sh

# 3. データ整合性チェック
mix event_store.check

# 4. サービス起動
docker compose up -d

# 5. 動作確認
./scripts/smoke_test.sh
```

#### 2. 部分的な障害

```bash
# 影響を受けたサービスの特定
kubectl get pods --all-namespaces | grep -v Running

# サービスの再起動
kubectl delete pod <pod-name>

# ログの確認
kubectl logs -f <pod-name>
```

## メンテナンス

### メンテナンスモード

```elixir
# メンテナンスモードの有効化
defmodule MaintenanceMode do
  def enable do
    File.write!("/tmp/maintenance_mode", "enabled")
  end

  def disable do
    File.rm("/tmp/maintenance_mode")
  end

  def enabled? do
    File.exists?("/tmp/maintenance_mode")
  end
end
```
