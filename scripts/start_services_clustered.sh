#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ログディレクトリの作成
mkdir -p "$PROJECT_ROOT/logs"

echo "Starting Elixir CQRS Services in clustered mode..."

# Docker コンテナの確認
echo "Checking Docker containers..."
docker compose ps

# Command Service の起動（名前付きノード）
echo "Starting Command Service..."
cd "$PROJECT_ROOT/apps/command_service" || exit 1
elixir --name command@127.0.0.1 --cookie elixir_cqrs_secret -S mix run --no-halt > "$PROJECT_ROOT/logs/command_service.log" 2>&1 &
COMMAND_PID=$!
echo "Command Service started with PID: $COMMAND_PID"

# 少し待機
sleep 5

# Query Service の起動（名前付きノード）
echo "Starting Query Service..."
cd "$PROJECT_ROOT/apps/query_service" || exit 1
elixir --name query@127.0.0.1 --cookie elixir_cqrs_secret -S mix run --no-halt > "$PROJECT_ROOT/logs/query_service.log" 2>&1 &
QUERY_PID=$!
echo "Query Service started with PID: $QUERY_PID"

# 少し待機
sleep 5

# Client Service の起動（名前付きノード）
echo "Starting Client Service..."
cd "$PROJECT_ROOT/apps/client_service" || exit 1
elixir --name client@127.0.0.1 --cookie elixir_cqrs_secret -S mix phx.server > "$PROJECT_ROOT/logs/client_service.log" 2>&1 &
CLIENT_PID=$!
echo "Client Service started with PID: $CLIENT_PID"

echo ""
echo "All services started in clustered mode!"
echo "Command Service PID: $COMMAND_PID (node: command@127.0.0.1)"
echo "Query Service PID: $QUERY_PID (node: query@127.0.0.1)"
echo "Client Service PID: $CLIENT_PID (node: client@127.0.0.1)"
echo ""
echo "GraphQL Playground: http://localhost:4000/graphql"
echo "Logs are available in: $PROJECT_ROOT/logs/"
echo ""
echo "To connect nodes manually, use:"
echo "  Node.connect(:'command@127.0.0.1')"
echo "  Node.connect(:'query@127.0.0.1')"
echo "  Node.connect(:'client@127.0.0.1')"
echo ""
echo "Press Ctrl+C to stop all services"

# シグナルハンドラーの設定
trap 'echo "Stopping services..."; kill $COMMAND_PID $QUERY_PID $CLIENT_PID 2>/dev/null; exit' INT TERM

# プロセスの監視
wait