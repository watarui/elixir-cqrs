#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
if ! mix deps.get; then
    echo "依存関係の取得に失敗しました"
    exit 1
fi

# 各アプリケーションのデータベースセットアップ
echo "=== Shared Service (Event Store) のセットアップ ==="
cd "$PROJECT_ROOT/apps/shared"
if mix ecto.create; then
    echo "Event Store データベースが作成されました"
else
    echo "Event Store データベースは既に存在します"
fi

if mix ecto.migrate; then
    echo "Event Store マイグレーションが完了しました"
else
    echo "Event Store マイグレーションに失敗しました"
    exit 1
fi

echo ""
echo "=== Command Service のセットアップ ==="
cd "$PROJECT_ROOT/apps/command_service"
if mix ecto.create; then
    echo "Command Service データベースが作成されました"
else
    echo "Command Service データベースは既に存在します"
fi

if mix ecto.migrate; then
    echo "Command Service マイグレーションが完了しました"
else
    echo "Command Service マイグレーションに失敗しました"
    exit 1
fi

echo ""
echo "=== Query Service のセットアップ ==="
cd "$PROJECT_ROOT/apps/query_service"
if mix ecto.create; then
    echo "Query Service データベースが作成されました"
else
    echo "Query Service データベースは既に存在します"
fi

if mix ecto.migrate; then
    echo "Query Service マイグレーションが完了しました"
else
    echo "Query Service マイグレーションに失敗しました"
    exit 1
fi

# プロジェクトのルートに戻る
cd "$PROJECT_ROOT"

echo ""
echo "=== データベースセットアップが完了しました ==="
echo ""
echo "次のステップ:"
echo "1. サービスを起動: ./scripts/start_services_clustered.sh"
echo "2. または個別に起動:"
echo "   - Command Service: cd apps/command_service && mix run --no-halt"
echo "   - Query Service: cd apps/query_service && mix run --no-halt"
echo "   - Client Service: cd apps/client_service && mix phx.server"
echo ""
echo "GraphQL Playground: http://localhost:4000/graphiql"
echo ""

# データベースの状態確認
echo "=== データベースの状態確認 ==="
echo "Event Store Database (5432):"
psql -h localhost -p 5432 -U postgres -d elixir_cqrs_event_store_dev -c "\dt" 2>/dev/null || echo "  接続エラーまたはテーブルが存在しません"

echo ""
echo "Command Service Database (5433):"
psql -h localhost -p 5433 -U postgres -d elixir_cqrs_command_dev -c "\dt" 2>/dev/null || echo "  接続エラーまたはテーブルが存在しません"

echo ""
echo "Query Service Database (5434):"
psql -h localhost -p 5434 -U postgres -d elixir_cqrs_query_dev -c "\dt" 2>/dev/null || echo "  接続エラーまたはテーブルが存在しません"

echo ""
echo "セットアップが完了しました！"
