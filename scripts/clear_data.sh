#!/bin/bash

# データベースのデータをクリアするスクリプト

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 色付き出力用の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# フラグの処理
FORCE=false
if [ "$1" == "-y" ] || [ "$1" == "--yes" ]; then
    FORCE=true
fi

echo "🗑️  データベースのデータをクリアします"
echo "========================================"
echo ""

# 確認プロンプト
if [ "$FORCE" != true ]; then
    echo -e "${YELLOW}⚠️  警告: この操作により、すべてのデータが削除されます。${NC}"
    echo ""
    echo "削除されるデータ:"
    echo "  - すべてのカテゴリ"
    echo "  - すべての商品"
    echo "  - すべての注文"
    echo "  - すべてのイベント"
    echo "  - すべての Saga"
    echo ""
    read -p "本当に続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "キャンセルしました。"
        exit 0
    fi
fi

# Docker コンテナが起動しているか確認
if ! docker compose ps | grep -q "postgres-event-store.*running"; then
    echo -e "${RED}❌ PostgreSQL コンテナが起動していません${NC}"
    echo "  ./scripts/start_all.sh を実行してください"
    exit 1
fi

echo ""
echo -e "${YELLOW}🔧 データベースをクリアしています...${NC}"

# 各データベースのテーブルをトランケート
echo "  - Event Store をクリア..."
docker compose exec -T postgres-event-store psql -U postgres -d elixir_cqrs_event_store_dev -c "
    TRUNCATE TABLE events CASCADE;
    TRUNCATE TABLE snapshots CASCADE;
    TRUNCATE TABLE sagas CASCADE;
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "    ${GREEN}✅ Event Store をクリアしました${NC}"
else
    echo -e "    ${RED}❌ Event Store のクリアに失敗しました${NC}"
fi

echo "  - Command DB をクリア..."
docker compose exec -T postgres-command psql -U postgres -d elixir_cqrs_command_dev -c "
    TRUNCATE TABLE products CASCADE;
    TRUNCATE TABLE categories CASCADE;
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "    ${GREEN}✅ Command DB をクリアしました${NC}"
else
    echo -e "    ${RED}❌ Command DB のクリアに失敗しました${NC}"
fi

echo "  - Query DB をクリア..."
docker compose exec -T postgres-query psql -U postgres -d elixir_cqrs_query_dev -c "
    TRUNCATE TABLE products CASCADE;
    TRUNCATE TABLE categories CASCADE;
    TRUNCATE TABLE orders CASCADE;
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "    ${GREEN}✅ Query DB をクリアしました${NC}"
else
    echo -e "    ${RED}❌ Query DB のクリアに失敗しました${NC}"
fi

# シーケンスのリセット
echo ""
echo -e "${BLUE}📊 シーケンスをリセットしています...${NC}"
docker compose exec -T postgres-event-store psql -U postgres -d elixir_cqrs_event_store_dev -c "
    ALTER SEQUENCE events_global_sequence_seq RESTART WITH 1;
" > /dev/null 2>&1

echo ""
echo "========================================"
echo -e "${GREEN}✅ データベースのクリアが完了しました${NC}"
echo "========================================"
echo ""
echo "📌 次のステップ:"
echo "  - デモデータを投入: mix run scripts/seed_demo_data.exs"
echo "  - サービスを再起動: ./scripts/stop_all.sh && ./scripts/start_all.sh"
echo ""