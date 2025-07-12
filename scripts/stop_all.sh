#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 色付き出力用の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🛑 サービスを停止します"
echo "======================="
echo ""

# オプションの処理
STOP_DOCKER=false

for arg in "$@"; do
    case $arg in
        --all)
            STOP_DOCKER=true
            shift
            ;;
        --help)
            echo "使用方法: $0 [オプション]"
            echo ""
            echo "オプション:"
            echo "  --all     Docker コンテナも停止します"
            echo "  --help    このヘルプを表示します"
            exit 0
            ;;
    esac
done

# 1. フロントエンドプロセスの停止
echo -e "${YELLOW}🎨 フロントエンドプロセスを停止しています...${NC}"
FRONTEND_PIDS=$(pgrep -f "bun.*dev.*4001" || true)
if [ ! -z "$FRONTEND_PIDS" ]; then
    kill $FRONTEND_PIDS 2>/dev/null
    echo -e "${GREEN}✅ フロントエンドを停止しました${NC}"
else
    echo "  フロントエンドプロセスは起動していません"
fi

# 2. Elixir バックエンドサービスの停止
echo ""
echo -e "${YELLOW}⚡ Elixir サービスを停止しています...${NC}"
"$SCRIPT_DIR/stop_services.sh"
echo -e "${GREEN}✅ Elixir サービスを停止しました${NC}"

# 3. Docker コンテナの停止（オプション）
if [ $STOP_DOCKER = true ]; then
    echo ""
    echo -e "${YELLOW}📦 Docker コンテナを停止しています...${NC}"
    echo "  - PostgreSQL データベース"
    echo "  - Jaeger, Prometheus, Grafana"
    if docker compose ps | grep -q pgadmin; then
        echo "  - pgAdmin"
    fi
    cd "$PROJECT_ROOT"
    docker compose down
    echo -e "${GREEN}✅ Docker コンテナを停止しました${NC}"
else
    echo ""
    echo -e "${YELLOW}ℹ️  Docker コンテナは起動したままです${NC}"
    echo "  Docker コンテナも停止する場合は --all オプションを使用してください"
    echo ""
    echo "📋 起動中の Docker コンテナ:"
    docker compose ps --format "table {{.Name}}\t{{.Status}}"
fi

# ログファイルのクリーンアップ（オプション）
echo ""
read -p "ログファイルをクリアしますか？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "ログファイルをクリアしています..."
    rm -f "$PROJECT_ROOT/logs/*.log"
    echo -e "${GREEN}✅ ログファイルをクリアしました${NC}"
fi

echo ""
echo "======================================="
echo -e "${GREEN}✅ 停止処理が完了しました${NC}"
echo "======================================="
echo ""
echo "📌 次のコマンド:"
echo "  - すべて再起動: ./scripts/start_all.sh"
echo "  - インフラのみ起動: ./scripts/setup_infra.sh"
echo "  - バックエンドのみ起動: ./scripts/start_services.sh"
echo ""