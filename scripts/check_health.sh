#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 色付き出力用の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🏥 サービスヘルスチェック"
echo "========================"
echo ""

# ヘルスチェック結果を格納
HEALTH_STATUS=0

# PostgreSQL データベースの確認
echo "📊 PostgreSQL データベース:"
for db_info in "5432:Event Store" "5433:Command Service" "5434:Query Service"; do
    IFS=':' read -r port name <<< "$db_info"
    if pg_isready -h localhost -p $port -U postgres >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} $name (port $port) - 正常"
    else
        echo -e "  ${RED}❌${NC} $name (port $port) - 接続できません"
        HEALTH_STATUS=1
    fi
done

# Elixir サービスの確認
echo ""
echo "⚡ Elixir サービス:"
for service in "command@127.0.0.1" "query@127.0.0.1" "client@127.0.0.1"; do
    if ps aux | grep -q "elixir.*--name $service"; then
        echo -e "  ${GREEN}✅${NC} $service - 起動中"
    else
        echo -e "  ${YELLOW}⚠️${NC}  $service - 停止中"
    fi
done

# GraphQL エンドポイントの確認
echo ""
echo "🌐 GraphQL エンドポイント:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/graphql | grep -q "200\|404"; then
    echo -e "  ${GREEN}✅${NC} http://localhost:4000/graphql - アクセス可能"
else
    echo -e "  ${RED}❌${NC} http://localhost:4000/graphql - アクセスできません"
    HEALTH_STATUS=1
fi

# フロントエンドの確認
echo ""
echo "🎨 フロントエンド:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:4001 | grep -q "200\|404"; then
    echo -e "  ${GREEN}✅${NC} http://localhost:4001 - アクセス可能"
else
    echo -e "  ${YELLOW}⚠️${NC}  http://localhost:4001 - 起動していません"
fi

# 監視サービスの確認
echo ""
echo "📈 監視サービス:"
services=(
    "16686:Jaeger UI"
    "9090:Prometheus"
    "3000:Grafana"
)

for service_info in "${services[@]}"; do
    IFS=':' read -r port name <<< "$service_info"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$port | grep -q "200\|302"; then
        echo -e "  ${GREEN}✅${NC} $name (http://localhost:$port) - アクセス可能"
    else
        echo -e "  ${YELLOW}⚠️${NC}  $name (http://localhost:$port) - アクセスできません"
    fi
done

# Docker コンテナの状態
echo ""
echo "🐳 Docker コンテナ:"
docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"

# メモリ使用状況
echo ""
echo "💾 リソース使用状況:"
if command -v docker stats >/dev/null 2>&1; then
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10
fi

# 総合的な状態
echo ""
echo "======================================="
if [ $HEALTH_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ すべての必須サービスが正常に動作しています${NC}"
else
    echo -e "${RED}❌ 一部のサービスに問題があります${NC}"
    echo ""
    echo "問題を解決するには:"
    echo "  1. Docker が起動していることを確認: docker ps"
    echo "  2. インフラを再起動: ./scripts/setup_infra.sh"
    echo "  3. サービスを再起動: ./scripts/start_services.sh"
fi
echo "======================================="

exit $HEALTH_STATUS