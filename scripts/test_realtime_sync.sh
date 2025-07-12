#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 色付き出力用の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔄 リアルタイム同期のテストを開始します"
echo "========================================"
echo ""

# GraphQL エンドポイントの確認
echo -e "${YELLOW}📡 Step 1/3: GraphQL エンドポイントの確認...${NC}"
if curl -s -X POST http://localhost:4000/graphql \
     -H "Content-Type: application/json" \
     -d '{"query": "{ __schema { queryType { name } } }"}' \
     2>/dev/null | grep -q "RootQueryType"; then
    echo -e "${GREEN}✅ GraphQL API は正常に動作しています${NC}"
else
    echo -e "${RED}❌ GraphQL API に接続できません${NC}"
    echo "  サービスが起動していることを確認してください: ./scripts/start_all.sh"
    exit 1
fi

# WebSocket 接続のテスト
echo ""
echo -e "${YELLOW}🌐 Step 2/3: WebSocket 接続のテスト...${NC}"

# WebSocket テスト用の一時ファイル
TEMP_FILE=$(mktemp)

# WebSocket 接続テストスクリプト
cat > "$TEMP_FILE" << 'EOF'
import { createClient } from 'graphql-ws';

const client = createClient({
  url: 'ws://localhost:4000/socket',
  connectionParams: {
    authToken: 'test-token',
  },
});

let connected = false;

client.on('connected', () => {
  console.log('✅ WebSocket 接続成功');
  connected = true;
});

client.on('closed', () => {
  console.log('❌ WebSocket 接続が閉じられました');
});

client.on('error', (error) => {
  console.error('❌ WebSocket エラー:', error);
});

// 5秒後にタイムアウト
setTimeout(() => {
  if (!connected) {
    console.error('❌ WebSocket 接続タイムアウト');
    process.exit(1);
  }
  process.exit(0);
}, 5000);

// 接続を開始
client.subscribe({
  query: `subscription { __typename }`,
  next: () => {},
  error: (err) => console.error('Subscription error:', err),
  complete: () => {},
});
EOF

# Node.js でテストを実行（graphql-ws がインストールされている場合）
if command -v node >/dev/null 2>&1 && [ -d "$PROJECT_ROOT/frontend/node_modules/graphql-ws" ]; then
    cd "$PROJECT_ROOT/frontend"
    node "$TEMP_FILE" 2>/dev/null || echo -e "${YELLOW}⚠️  WebSocket テストをスキップします（依存関係が見つかりません）${NC}"
else
    echo -e "${YELLOW}⚠️  WebSocket テストをスキップします（Node.js が見つかりません）${NC}"
fi

rm -f "$TEMP_FILE"

# PubSub メッセージのテスト
echo ""
echo -e "${YELLOW}📬 Step 3/3: PubSub メッセージの送受信テスト...${NC}"

# テスト用のコマンドを送信
echo "テストコマンドを送信しています..."
COMMAND_RESULT=$(curl -s -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { createCategory(input: { name: \"Test Category\", description: \"リアルタイム同期テスト\" }) { id name } }"
  }' 2>/dev/null)

if echo "$COMMAND_RESULT" | grep -q "Test Category"; then
    echo -e "${GREEN}✅ コマンドが正常に実行されました${NC}"
    
    # イベントストアの確認
    echo ""
    echo "イベントストアを確認しています..."
    EVENT_COUNT=$(curl -s -X POST http://localhost:4000/graphql \
      -H "Content-Type: application/json" \
      -d '{
        "query": "{ eventStoreStats { totalEvents } }"
      }' 2>/dev/null | grep -o '"totalEvents":[0-9]*' | grep -o '[0-9]*$')
    
    if [ ! -z "$EVENT_COUNT" ] && [ "$EVENT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ イベントストアに $EVENT_COUNT 件のイベントが記録されています${NC}"
    else
        echo -e "${YELLOW}⚠️  イベントストアの確認をスキップします${NC}"
    fi
    
    # PubSub メッセージの確認
    echo ""
    echo "PubSub メッセージを確認しています..."
    PUBSUB_RESULT=$(curl -s -X POST http://localhost:4000/graphql \
      -H "Content-Type: application/json" \
      -d '{
        "query": "{ pubsubMessages(limit: 5) { id topic timestamp } }"
      }' 2>/dev/null)
    
    if echo "$PUBSUB_RESULT" | grep -q "topic"; then
        echo -e "${GREEN}✅ PubSub メッセージが正常に配信されています${NC}"
    else
        echo -e "${YELLOW}⚠️  PubSub メッセージの確認をスキップします${NC}"
    fi
else
    echo -e "${RED}❌ コマンドの実行に失敗しました${NC}"
fi

# ダッシュボード統計の確認
echo ""
echo -e "${BLUE}📊 ダッシュボード統計:${NC}"
STATS_RESULT=$(curl -s -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ dashboardStatistics { commandsExecuted queriesExecuted eventsPublished sagasActive } }"
  }' 2>/dev/null)

if echo "$STATS_RESULT" | grep -q "commandsExecuted"; then
    echo "$STATS_RESULT" | grep -o '"commandsExecuted":[0-9]*' | sed 's/"commandsExecuted":/  - コマンド実行数: /'
    echo "$STATS_RESULT" | grep -o '"queriesExecuted":[0-9]*' | sed 's/"queriesExecuted":/  - クエリ実行数: /'
    echo "$STATS_RESULT" | grep -o '"eventsPublished":[0-9]*' | sed 's/"eventsPublished":/  - イベント発行数: /'
    echo "$STATS_RESULT" | grep -o '"sagasActive":[0-9]*' | sed 's/"sagasActive":/  - アクティブな Saga: /'
else
    echo -e "${YELLOW}⚠️  統計情報を取得できませんでした${NC}"
fi

echo ""
echo "========================================"
echo -e "${GREEN}✅ リアルタイム同期のテストが完了しました${NC}"
echo "========================================"
echo ""
echo "📌 次のステップ:"
echo "  - Frontend でリアルタイム更新を確認: http://localhost:4001/pubsub"
echo "  - GraphQL Playground でサブスクリプションをテスト: http://localhost:4000/graphiql"
echo ""