#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 環境変数を設定してElixirの警告を抑制
export MIX_QUIET=1
export PGPASSWORD=postgres

echo "=== Elixir CQRS データベースセットアップ ==="
echo "プロジェクト root: $PROJECT_ROOT"
echo ""

# エラーが発生した場合にスクリプトを終了
set -e

# Docker コンテナの起動確認
echo "Docker コンテナの状態を確認しています..."
if ! docker compose ps | grep -q "postgres.*Up"; then
    echo "PostgreSQL コンテナが起動していません。以下のコマンドを実行してください："
    echo "docker compose up -d"
    exit 1
fi

# データベースの接続確認
echo "データベースへの接続を確認しています..."

# Event Store Database (port 5432)
until pg_isready -h localhost -p 5432 -U postgres; do
    echo "Event Store Database (5432) の起動を待機中..."
    sleep 2
done

# Command Service Database (port 5433)
until pg_isready -h localhost -p 5433 -U postgres; do
    echo "Command Service Database (5433) の起動を待機中..."
    sleep 2
done

# Query Service Database (port 5434)
until pg_isready -h localhost -p 5434 -U postgres; do
    echo "Query Service Database (5434) の起動を待機中..."
    sleep 2
done

echo "すべてのデータベースが利用可能です。"
echo ""

# プロジェクトのルートディレクトリに移動
cd "$PROJECT_ROOT"

# 依存関係の確認
echo "依存関係を確認しています..."
if ! mix deps.get >/dev/null 2>&1; then
    echo "依存関係の取得に失敗しました"
    exit 1
fi

# 各アプリケーションのデータベースセットアップ
echo "=== Shared Service (Event Store) のセットアップ ==="
cd "$PROJECT_ROOT/apps/shared"

# データベース作成
echo "Event Store データベースを作成中..."
if mix ecto.create --repo Shared.Infrastructure.EventStore.Repo 2>&1 | grep -v "already exists"; then
    echo "Event Store データベースが作成されました"
else
    echo "Event Store データベースは既に存在します"
fi

# マイグレーションの実行
echo "Event Store マイグレーションを実行中..."
MIGRATION_RESULT=$(mix ecto.migrate --repo Shared.Infrastructure.EventStore.Repo 2>&1)
if echo "$MIGRATION_RESULT" | grep -E "(error|Error|failed|Failed)" > /dev/null; then
    echo "Event Store マイグレーションに失敗しました:"
    echo "$MIGRATION_RESULT"
    exit 1
elif echo "$MIGRATION_RESULT" | grep -E "(Already up|Migrated)"; then
    echo "Event Store マイグレーションが完了しました"
else
    echo "Event Store マイグレーション結果:"
    echo "$MIGRATION_RESULT"
fi

echo ""
echo "=== Command Service のセットアップ ==="
cd "$PROJECT_ROOT/apps/command_service"
mix ecto.create 2>&1 | grep -v "already exists" || true
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "Command Service データベースが作成されました"
else
    echo "Command Service データベースは既に存在します"
fi

# マイグレーションの実行（エラーのみ表示）
if mix ecto.migrate 2>&1 | grep -E "(error|Error|failed|Failed)"; then
    echo "Command Service マイグレーションに失敗しました"
    exit 1
else
    echo "Command Service マイグレーションが完了しました"
fi

echo ""
echo "=== Query Service のセットアップ ==="
cd "$PROJECT_ROOT/apps/query_service"
mix ecto.create 2>&1 | grep -v "already exists" || true
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "Query Service データベースが作成されました"
else
    echo "Query Service データベースは既に存在します"
fi

# マイグレーションの実行（エラーのみ表示）
if mix ecto.migrate 2>&1 | grep -E "(error|Error|failed|Failed)"; then
    echo "Query Service マイグレーションに失敗しました"
    exit 1
else
    echo "Query Service マイグレーションが完了しました"
fi

# プロジェクトのルートに戻る
cd "$PROJECT_ROOT"

echo ""
echo "=== データベースセットアップが完了しました ==="
echo ""
echo "次のステップ:"
echo "サービスを起動: ./scripts/start_services.sh"
echo ""
echo "GraphQL Playground: http://localhost:4000/graphiql"
echo ""

# データベースの状態確認
echo "=== データベースの状態確認 ==="
echo "Event Store Database (5432):"
PGPASSWORD=$PGPASSWORD psql -h localhost -p 5432 -U postgres -d elixir_cqrs_event_store_dev -c "\dt" 2>/dev/null || echo "  接続エラーまたはテーブルが存在しません"

echo ""
echo "Command Service Database (5433):"
PGPASSWORD=$PGPASSWORD psql -h localhost -p 5433 -U postgres -d elixir_cqrs_command_dev -c "\dt" 2>/dev/null || echo "  接続エラーまたはテーブルが存在しません"

echo ""
echo "Query Service Database (5434):"
PGPASSWORD=$PGPASSWORD psql -h localhost -p 5434 -U postgres -d elixir_cqrs_query_dev -c "\dt" 2>/dev/null || echo "  接続エラーまたはテーブルが存在しません"

echo ""

# デモデータの投入オプション
if [ "$1" = "--with-demo-data" ]; then
    echo "=== デモデータの投入 ==="
    cd "$PROJECT_ROOT"
    mix run scripts/seed_demo_data.exs
    echo "デモデータの投入が完了しました"
    echo ""
fi

echo "セットアップが完了しました！"

if [ "$1" != "--with-demo-data" ]; then
    echo ""
    echo "デモデータを投入する場合は以下を実行してください："
    echo "  mix run scripts/seed_demo_data.exs"
    echo "または："
    echo "  ./scripts/setup_db.sh --with-demo-data"
fi
