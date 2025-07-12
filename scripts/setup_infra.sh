#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Docker インフラストラクチャの起動 ==="
echo ""

# Docker の起動確認
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker が起動していません。Docker Desktop を起動してください。"
    exit 1
fi

# プロジェクトルートに移動
cd "$PROJECT_ROOT" || exit

# Docker Compose でインフラを起動
echo "📦 PostgreSQL データベースを起動しています..."
docker compose up -d postgres-event-store postgres-command postgres-query

echo "📊 監視・メトリクスサービスを起動しています..."
docker compose up -d jaeger prometheus grafana

echo "🗜️  pgweb を起動しています..."
docker compose up -d pgweb-event-store pgweb-command pgweb-query

# 起動確認
echo ""
echo "⏳ サービスの起動を確認しています..."
sleep 5

# PostgreSQL の起動確認
echo ""
echo "🔍 PostgreSQL の状態確認..."
for port in 5432 5433 5434; do
    if docker compose exec postgres-event-store pg_isready -U postgres >/dev/null 2>&1; then
        echo "  ✅ PostgreSQL (port $port) - 起動完了"
    else
        echo "  ⚠️  PostgreSQL (port $port) - 起動中..."
    fi
done

# サービスの状態表示
echo ""
echo "📋 起動したサービス:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== インフラストラクチャの起動が完了しました ==="
echo ""
echo "🌐 アクセス URL:"
echo "  - Jaeger UI: http://localhost:16686"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/admin)"
echo "  - pgweb event store: http://localhost:5050"
echo "  - pgweb command db: http://localhost:5051"
echo "  - pgweb query db: http://localhost:5052"
echo ""
echo "次のステップ:"
echo "  1. データベースセットアップ: ./scripts/setup_db.sh"
echo "  2. サービスの起動: ./scripts/start_services.sh"
echo ""
