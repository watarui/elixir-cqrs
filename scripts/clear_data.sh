#!/bin/bash

# データベースのデータをクリアするスクリプト
#
# 使用方法:
#   ./scripts/clear_data.sh        # 確認プロンプトを表示
#   ./scripts/clear_data.sh -y     # 確認プロンプトをスキップ

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# コンテナが起動しているか確認
check_containers() {
    if ! docker compose ps | grep -q "postgres" || ! docker compose ps | grep -q "Up"; then
        echo -e "${RED}❌ エラー: Docker コンテナが起動していません${NC}"
        echo "まず ./scripts/setup_infra.sh を実行してください"
        exit 1
    fi
}

# 確認プロンプト
confirm_clear() {
    if [ "$1" != "-y" ]; then
        echo -e "${YELLOW}⚠️  警告: すべてのデータが削除されます！${NC}"
        echo ""
        echo "以下のデータベースのすべてのデータが削除されます:"
        echo "  - Command DB (カテゴリ、商品、注文)"
        echo "  - Event Store (すべてのイベント)"
        echo "  - Query DB (プロジェクション)"
        echo ""
        read -p "本当に続行しますか？ (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "キャンセルしました"
            exit 0
        fi
    fi
}

# データベースをクリア
clear_databases() {
    echo ""
    echo "🗑️  データベースのクリアを開始します..."
    
    # Command DB
    echo ""
    echo "📦 Command DB をクリアしています..."
    docker compose exec postgres-command psql -U postgres -d elixir_cqrs_command_dev -c "
        TRUNCATE TABLE orders CASCADE;
        TRUNCATE TABLE products CASCADE;
        TRUNCATE TABLE categories CASCADE;
        TRUNCATE TABLE sagas CASCADE;
    " > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Command DB をクリアしました${NC}"
    else
        echo -e "${RED}❌ Command DB のクリアに失敗しました${NC}"
    fi
    
    # Event Store
    echo ""
    echo "📚 Event Store をクリアしています..."
    docker compose exec postgres-event-store psql -U postgres -d elixir_cqrs_event_store_dev -c "
        TRUNCATE TABLE events CASCADE;
        TRUNCATE TABLE snapshots CASCADE;
    " > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Event Store をクリアしました${NC}"
    else
        echo -e "${RED}❌ Event Store のクリアに失敗しました${NC}"
    fi
    
    # Query DB
    echo ""
    echo "🔍 Query DB をクリアしています..."
    docker compose exec postgres-query psql -U postgres -d elixir_cqrs_query_dev -c "
        TRUNCATE TABLE orders CASCADE;
        TRUNCATE TABLE products CASCADE;
        TRUNCATE TABLE categories CASCADE;
    " > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Query DB をクリアしました${NC}"
    else
        echo -e "${RED}❌ Query DB のクリアに失敗しました${NC}"
    fi
}

# メイン処理
main() {
    echo "========================================"
    echo "🗑️  CQRS/ES データクリアツール"
    echo "========================================"
    
    # コンテナの確認
    check_containers
    
    # 確認プロンプト
    confirm_clear "$1"
    
    # データベースをクリア
    clear_databases
    
    echo ""
    echo "========================================"
    echo -e "${GREEN}✅ すべてのデータをクリアしました${NC}"
    echo "========================================"
    echo ""
    echo "📌 次のステップ:"
    echo "  - デモデータを投入: ./scripts/run_seed_data.sh"
    echo "  - サービスを再起動: ./scripts/stop_all.sh && ./scripts/start_all.sh"
}

# スクリプトを実行
main "$@"