#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 色付き出力用の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Elixir CQRS/ES 開発環境を起動します"
echo "========================================"
echo ""

# フラグの処理
WITH_FRONTEND=false
WITH_DEMO_DATA=false

for arg in "$@"; do
    case $arg in
        --with-frontend)
            WITH_FRONTEND=true
            shift
            ;;
        --with-demo-data)
            WITH_DEMO_DATA=true
            shift
            ;;
        --help)
            echo "使用方法: $0 [オプション]"
            echo ""
            echo "オプション:"
            echo "  --with-frontend    フロントエンドも起動します"
            echo "  --with-demo-data   デモデータを投入します"
            echo "  --help            このヘルプを表示します"
            exit 0
            ;;
    esac
done

# 1. Docker インフラの起動
echo -e "${YELLOW}📦 Step 1/4: Docker インフラストラクチャを起動しています...${NC}"
"$SCRIPT_DIR/setup_infra.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ インフラの起動に失敗しました${NC}"
    exit 1
fi

# 2. 依存関係の取得
echo ""
echo -e "${YELLOW}📦 Step 2/5: 依存関係を確認しています...${NC}"
cd "$PROJECT_ROOT"
mix deps.get > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 依存関係の取得が完了しました${NC}"
else
    echo -e "${RED}❌ 依存関係の取得に失敗しました${NC}"
    exit 1
fi

# 3. データベースのセットアップ確認
echo ""
echo -e "${YELLOW}🗄️  Step 3/5: データベースの状態を確認しています...${NC}"

# データベースが既に存在するかチェック
DB_EXISTS=$(PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -lqt | cut -d \| -f 1 | grep -w elixir_cqrs_event_store_dev | wc -l)

# テーブルの存在確認関数
check_tables() {
    local db_name=$1
    local port=$2
    local count=$(docker compose exec -T postgres-${db_name} psql -U postgres -d elixir_cqrs_${db_name}_dev -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" 2>/dev/null | tr -d ' ')
    echo ${count:-0}
}

if [ $DB_EXISTS -eq 0 ]; then
    echo "データベースが存在しません。セットアップを実行します..."
    "$SCRIPT_DIR/setup_db.sh"
    NEED_DEMO_DATA=true
else
    # テーブルの存在確認
    QUERY_TABLES=$(check_tables "query" "5434")
    COMMAND_TABLES=$(check_tables "command" "5433")
    EVENT_TABLES=$(check_tables "event-store" "5432")
    
    echo "テーブル数 - Query: $QUERY_TABLES, Command: $COMMAND_TABLES, Event: $EVENT_TABLES"
    
    if [ "$QUERY_TABLES" -eq 0 ] || [ "$COMMAND_TABLES" -eq 0 ] || [ "$EVENT_TABLES" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  テーブルが存在しません。マイグレーションを実行します...${NC}"
        cd "$PROJECT_ROOT"
        
        # ログファイルの設定
        MIGRATION_LOG="$PROJECT_ROOT/logs/migration_$(date +%Y%m%d_%H%M%S).log"
        mkdir -p "$PROJECT_ROOT/logs"
        
        # マイグレーションを実行（警告はログファイルに出力）
        echo "マイグレーションログ: $MIGRATION_LOG" >> "$MIGRATION_LOG"
        
        # Event Store のマイグレーションを明示的に実行
        echo "Event Store マイグレーションを実行中..." >> "$MIGRATION_LOG"
        cd "$PROJECT_ROOT/apps/shared"
        mix ecto.migrate --repo Shared.Infrastructure.EventStore.Repo >> "$MIGRATION_LOG" 2>&1
        EVENT_STORE_RESULT=$?
        
        cd "$PROJECT_ROOT"
        # その他のマイグレーションを実行
        mix ecto.migrate --all >> "$MIGRATION_LOG" 2>&1
        MIGRATION_RESULT=$?
        
        if [ $MIGRATION_RESULT -eq 0 ]; then
            echo -e "${GREEN}✅ マイグレーションが完了しました${NC}"
            NEED_DEMO_DATA=true
        else
            echo -e "${RED}❌ マイグレーションに失敗しました${NC}"
            echo "詳細はログファイルを確認してください: $MIGRATION_LOG"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ データベースは既にセットアップ済みです${NC}"
        NEED_DEMO_DATA=false
    fi
fi

# デモデータの投入
if [ $WITH_DEMO_DATA = true ] && [ $NEED_DEMO_DATA = true ]; then
    echo "デモデータを投入しています..."
    "$SCRIPT_DIR/run_seed_data.sh"
fi

# 4. バックエンドサービスの起動
echo ""
echo -e "${YELLOW}⚡ Step 4/5: Elixir バックエンドサービスを起動しています...${NC}"
"$SCRIPT_DIR/start_services.sh" &
BACKEND_PID=$!

# バックエンドの起動を待つ
sleep 10

# GraphQL エンドポイントの確認
echo ""
echo "🔍 GraphQL エンドポイントの確認..."

# GraphQL API が完全に起動するまで待つ
MAX_ATTEMPTS=30
ATTEMPT=1
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if curl -s -X POST http://localhost:4000/graphql \
         -H "Content-Type: application/json" \
         -d '{"query": "{ __schema { queryType { name } } }"}' \
         2>/dev/null | grep -q "RootQueryType"; then
        echo -e "${GREEN}✅ GraphQL API が起動しました${NC}"
        break
    else
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo -e "${RED}❌ GraphQL API の起動に失敗しました${NC}"
            exit 1
        fi
        echo -e "${YELLOW}⚠️  GraphQL API の起動を待っています... ($ATTEMPT/$MAX_ATTEMPTS)${NC}"
        sleep 2
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

# 5. フロントエンドの起動（オプション）
if [ $WITH_FRONTEND = true ]; then
    echo ""
    echo -e "${YELLOW}🎨 Step 5/5: フロントエンドを起動しています...${NC}"
    
    # ポート 4001 が使用中かチェック
    if lsof -i :4001 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  ポート 4001 は既に使用中です。フロントエンドは既に起動している可能性があります。${NC}"
        FRONTEND_PID=""
    else
        cd "$PROJECT_ROOT/frontend"
        if [ ! -d "node_modules" ]; then
            echo "依存関係をインストールしています..."
            bun install
        fi
        
        bun run dev &
        FRONTEND_PID=$!
        
        # フロントエンドの起動を待つ
        sleep 5
        
        echo -e "${GREEN}✅ フロントエンドが起動しました${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}ℹ️  Step 5/5: フロントエンドはスキップされました${NC}"
    echo "  フロントエンドを起動する場合は --with-frontend オプションを使用してください"
fi

# 起動完了メッセージ
echo ""
echo "========================================"
echo -e "${GREEN}🎉 すべてのサービスが起動しました！${NC}"
echo "========================================"
echo ""
echo "📋 アクセス URL:"
echo "  - GraphQL Playground: http://localhost:4000/graphiql"
if [ $WITH_FRONTEND = true ]; then
    echo "  - Monitor Dashboard: http://localhost:4001"
fi
echo "  - Jaeger UI: http://localhost:16686"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3000 (admin/admin)"
echo "  - pgAdmin: http://localhost:5050 (admin@example.com/admin)"
echo ""
echo "📌 便利なコマンド:"
echo "  - ログを確認: tail -f $PROJECT_ROOT/logs/*.log"
echo "  - サービスを停止: ./scripts/stop_all.sh"
echo "  - Docker コンテナも停止: ./scripts/stop_all.sh --all"
echo ""
echo "Ctrl+C で全サービスを停止します"
echo ""

# シグナルハンドラーの設定
cleanup() {
    echo ""
    echo "🛑 サービスを停止しています..."
    
    # バックエンドプロセスを停止
    if [ ! -z "$BACKEND_PID" ]; then
        kill $BACKEND_PID 2>/dev/null
    fi
    
    # フロントエンドプロセスを停止
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null
    fi
    
    # Elixir プロセスを停止
    "$SCRIPT_DIR/stop_services.sh"
    
    echo "✅ すべてのサービスを停止しました"
    exit 0
}

trap cleanup INT TERM

# プロセスの監視
if [ $WITH_FRONTEND = true ]; then
    wait $BACKEND_PID $FRONTEND_PID
else
    wait $BACKEND_PID
fi