#!/bin/bash

# ノード起動問題を修正するスクリプト

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 色付き出力用の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔧 ノード起動問題の修正を開始します"
echo "========================================"
echo ""

# 1. EPMD の状態確認
echo -e "${YELLOW}📡 Step 1/5: EPMD (Erlang Port Mapper Daemon) の状態確認...${NC}"
if epmd -names 2>/dev/null | grep -q "epmd: up and running"; then
    echo -e "${GREEN}✅ EPMD は正常に動作しています${NC}"
    epmd -names
else
    echo -e "${YELLOW}⚠️  EPMD が起動していません。起動します...${NC}"
    epmd -daemon
    sleep 2
    if epmd -names 2>/dev/null | grep -q "epmd: up and running"; then
        echo -e "${GREEN}✅ EPMD を起動しました${NC}"
    else
        echo -e "${RED}❌ EPMD の起動に失敗しました${NC}"
    fi
fi

# 2. 既存の Elixir プロセスの確認
echo ""
echo -e "${YELLOW}🔍 Step 2/5: 既存の Elixir プロセスを確認...${NC}"
ELIXIR_PROCS=$(ps aux | grep -E "beam.smp.*elixir" | grep -v grep)
if [ -n "$ELIXIR_PROCS" ]; then
    echo "以下の Elixir プロセスが実行中です:"
    echo "$ELIXIR_PROCS" | awk '{print "  PID: " $2 " - " $11 " " $12}'
    
    read -p "これらのプロセスを停止しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "プロセスを停止しています..."
        ps aux | grep -E "beam.smp.*elixir" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
        sleep 2
        echo -e "${GREEN}✅ プロセスを停止しました${NC}"
    fi
else
    echo -e "${GREEN}✅ 実行中の Elixir プロセスはありません${NC}"
fi

# 3. ポートの使用状況確認
echo ""
echo -e "${YELLOW}🔌 Step 3/5: ポートの使用状況を確認...${NC}"
PORTS=(4000 4001 4369 9090 16686 3000 5432 5433 5434 5050 5051 5052)
BLOCKED_PORTS=()

for port in "${PORTS[@]}"; do
    if lsof -i :$port >/dev/null 2>&1; then
        PROCESS=$(lsof -i :$port | grep LISTEN | awk '{print $1}' | head -1)
        echo -e "${YELLOW}⚠️  ポート $port は使用中です (プロセス: $PROCESS)${NC}"
        BLOCKED_PORTS+=($port)
    fi
done

if [ ${#BLOCKED_PORTS[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ すべてのポートが利用可能です${NC}"
else
    echo -e "${YELLOW}⚠️  一部のポートが使用中です${NC}"
fi

# 4. Cookie の確認と設定
echo ""
echo -e "${YELLOW}🍪 Step 4/5: Erlang Cookie の確認...${NC}"
COOKIE_FILE="$HOME/.erlang.cookie"
if [ -f "$COOKIE_FILE" ]; then
    CURRENT_COOKIE=$(cat "$COOKIE_FILE")
    echo "現在の Cookie: ${CURRENT_COOKIE:0:8}..."
    
    # Cookie のパーミッション確認
    PERMS=$(stat -c %a "$COOKIE_FILE" 2>/dev/null || stat -f %p "$COOKIE_FILE" 2>/dev/null | tail -c 4)
    if [ "$PERMS" != "600" ] && [ "$PERMS" != "0600" ]; then
        echo -e "${YELLOW}⚠️  Cookie ファイルのパーミッションを修正しています...${NC}"
        chmod 600 "$COOKIE_FILE"
        echo -e "${GREEN}✅ パーミッションを修正しました${NC}"
    else
        echo -e "${GREEN}✅ Cookie ファイルのパーミッションは正常です${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Cookie ファイルが見つかりません。作成します...${NC}"
    echo "elixir-cqrs-secret-cookie" > "$COOKIE_FILE"
    chmod 600 "$COOKIE_FILE"
    echo -e "${GREEN}✅ Cookie ファイルを作成しました${NC}"
fi

# 5. ホスト名の解決確認
echo ""
echo -e "${YELLOW}🌐 Step 5/5: ホスト名の解決を確認...${NC}"
HOSTNAME=$(hostname)
echo "現在のホスト名: $HOSTNAME"

# /etc/hosts の確認
if grep -q "127.0.0.1.*localhost" /etc/hosts; then
    echo -e "${GREEN}✅ localhost の解決は正常です${NC}"
else
    echo -e "${RED}❌ /etc/hosts に localhost のエントリがありません${NC}"
    echo "以下の行を /etc/hosts に追加してください:"
    echo "127.0.0.1 localhost"
fi

# 環境変数の設定提案
echo ""
echo -e "${BLUE}📋 推奨される環境変数設定:${NC}"
echo "export ELIXIR_ERL_OPTIONS=\"+fnu\""
echo "export ERL_AFLAGS=\"-kernel shell_history enabled\""

# サービス起動スクリプトの存在確認
echo ""
echo -e "${BLUE}📋 サービス起動スクリプトの確認:${NC}"
SCRIPTS=("start_all.sh" "start_services.sh" "stop_all.sh" "stop_services.sh")
for script in "${SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        echo -e "  ✅ $script"
    else
        echo -e "  ❌ $script が見つかりません"
    fi
done

# まとめ
echo ""
echo "========================================"
echo -e "${GREEN}✅ ノード起動問題の修正が完了しました${NC}"
echo "========================================"
echo ""
echo "📌 次のステップ:"
echo "  1. サービスを起動: ./scripts/start_all.sh"
echo "  2. ノード接続を確認: mix run scripts/check_node_connection.exs"
echo ""

if [ ${#BLOCKED_PORTS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  注意: 以下のポートが使用中です:${NC}"
    printf '%s\n' "${BLOCKED_PORTS[@]}" | paste -sd ', ' -
    echo "  必要に応じて、関連するプロセスを停止してください。"
    echo ""
fi