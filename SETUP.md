# Elixir CQRS/ES 開発環境セットアップガイド

## 🚀 クイックスタート

最も簡単な方法：すべてのサービスを一度に起動

```bash
# バックエンド + フロントエンドを起動
./scripts/start_all.sh --with-frontend

# デモデータも投入する場合
./scripts/start_all.sh --with-frontend --with-demo-data
```

## 📋 前提条件

- **Elixir** 1.15 以上
- **Erlang/OTP** 25 以上
- **Docker** & Docker Compose
- **PostgreSQL** クライアント（`psql`、`pg_isready`）
- **Bun** または Node.js（フロントエンド用）

## 🔧 詳細なセットアップ手順

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd elixir-cqrs
```

### 2. 初回セットアップ

```bash
# Docker インフラの起動（PostgreSQL、Jaeger、Prometheus、Grafana）
./scripts/setup_infra.sh

# データベースの作成とマイグレーション
./scripts/setup_db.sh

# デモデータを投入する場合
./scripts/setup_db.sh --with-demo-data
```

### 3. 開発サーバーの起動

#### オプション A: すべて起動（推奨）
```bash
./scripts/start_all.sh --with-frontend
```

#### オプション B: 個別に起動
```bash
# インフラのみ
./scripts/setup_infra.sh

# バックエンドのみ
./scripts/start_services.sh

# フロントエンドのみ（別ターミナル）
cd frontend
bun install  # 初回のみ
bun run dev
```

#### オプション C: フロントエンドを Docker で起動
```bash
# バックエンドはローカル、フロントエンドは Docker
./scripts/start_services.sh
docker compose up monitor-dashboard
```

## 🌐 アクセス URL

| サービス | URL | 説明 |
|---------|-----|------|
| GraphQL Playground | http://localhost:4000/graphiql | GraphQL API の対話的テスト |
| Monitor Dashboard | http://localhost:4001 | CQRS/ES 監視ダッシュボード |
| Jaeger UI | http://localhost:16686 | 分散トレーシング |
| Prometheus | http://localhost:9090 | メトリクス収集 |
| Grafana | http://localhost:3000 | メトリクスダッシュボード（admin/admin） |

## 🛠️ 便利なコマンド

### サービス管理

```bash
# ヘルスチェック
./scripts/check_health.sh

# すべて停止
./scripts/stop_all.sh

# Docker も含めてすべて停止
./scripts/stop_all.sh --all

# ログの確認
tail -f logs/*.log
```

### フロントエンド開発

```bash
cd frontend

# 開発サーバー
bun run dev

# すべて起動（プロジェクトルートから実行）
bun run dev:all

# リンティング
bun run lint

# フォーマット
bun run format
```

### データベース操作

```bash
# マイグレーションの実行
mix ecto.migrate

# データベースのリセット
mix ecto.reset

# SAGA のクリーンアップ
mix cleanup_sagas
```

## 🐛 トラブルシューティング

### ポートが使用中の場合

```bash
# 使用中のポートを確認
lsof -i :4000  # GraphQL API
lsof -i :4001  # Monitor Dashboard
lsof -i :5432  # PostgreSQL

# プロセスを終了
kill -9 <PID>
```

### データベース接続エラー

```bash
# PostgreSQL の状態確認
docker compose ps

# データベースの再作成
docker compose down -v  # ボリュームも削除
./scripts/setup_infra.sh
./scripts/setup_db.sh
```

### フロントエンドが起動しない

```bash
cd frontend
rm -rf node_modules bun.lockb
bun install
bun run dev
```

## 📁 プロジェクト構造

```
elixir-cqrs/
├── apps/
│   ├── client_service/     # GraphQL API
│   ├── command_service/    # コマンドハンドラー
│   ├── query_service/      # クエリハンドラー
│   └── shared/            # 共通モジュール（EventStore、SAGA）
├── frontend/              # Next.js 監視ダッシュボード
├── scripts/               # 開発用スクリプト
├── k8s/                   # Kubernetes マニフェスト
├── docker-compose.yml     # Docker 構成
└── mix.exs               # Umbrella プロジェクト設定
```

## 🔍 開発のヒント

1. **GraphQL スキーマの確認**
   - http://localhost:4000/graphiql でスキーマを探索
   - Introspection クエリで型情報を取得

2. **イベントストアの確認**
   ```sql
   psql -h localhost -p 5432 -U postgres -d elixir_cqrs_event_store_dev
   SELECT * FROM events ORDER BY inserted_at DESC LIMIT 10;
   ```

3. **SAGA の状態確認**
   ```sql
   SELECT * FROM sagas WHERE status != 'completed' ORDER BY updated_at DESC;
   ```

4. **リアルタイムログ監視**
   ```bash
   # すべてのログを監視
   tail -f logs/*.log | grep -v DEBUG

   # 特定のサービスのみ
   tail -f logs/command_service.log
   ```

## 📚 関連ドキュメント

- [アーキテクチャ概要](docs/ARCHITECTURE.md)
- [CQRS パターン](docs/CQRS.md)
- [SAGA パターン](docs/SAGA.md)
- [イベントカタログ](docs/EVENTS.md)
- [GraphQL API](docs/API_GRAPHQL.md)