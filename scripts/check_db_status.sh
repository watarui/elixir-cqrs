#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 環境変数を設定
export PGPASSWORD=postgres
export MIX_QUIET=1

echo "=== データベース状態チェック ==="
echo ""

# PostgreSQL の接続確認
echo "📊 PostgreSQL 接続状態:"
for port in 5432 5433 5434; do
    if pg_isready -h localhost -p $port -U postgres >/dev/null 2>&1; then
        echo "  ✅ Port $port - 接続可能"
    else
        echo "  ❌ Port $port - 接続不可"
    fi
done

echo ""
echo "📋 データベース一覧:"
psql -h localhost -p 5432 -U postgres -lqt | cut -d \| -f 1 | grep elixir_cqrs | sed 's/^/  - /'

echo ""
echo "🔍 各サービスのマイグレーション状態:"

# Event Store
echo ""
echo "Event Store Database (port 5432):"
cd "$PROJECT_ROOT/apps/shared" && mix ecto.migrations 2>/dev/null || echo "  マイグレーション情報を取得できません"

# Command Service
echo ""
echo "Command Service Database (port 5433):"
cd "$PROJECT_ROOT/apps/command_service" && mix ecto.migrations 2>/dev/null || echo "  マイグレーション情報を取得できません"

# Query Service
echo ""
echo "Query Service Database (port 5434):"
cd "$PROJECT_ROOT/apps/query_service" && mix ecto.migrations 2>/dev/null || echo "  マイグレーション情報を取得できません"

# テーブルの確認
echo ""
echo "📊 Query Service のテーブル一覧:"
PGPASSWORD=$PGPASSWORD psql -h localhost -p 5434 -U postgres -d elixir_cqrs_query_dev -c "\dt" 2>/dev/null || echo "  接続エラーまたはデータベースが存在しません"

echo ""
echo "✅ チェック完了"