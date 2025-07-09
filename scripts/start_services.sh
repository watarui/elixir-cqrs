#!/bin/bash

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ログディレクトリの作成
mkdir -p "$PROJECT_ROOT/logs"

echo "Starting Elixir CQRS Services..."

# Docker コンテナの確認
echo "Checking Docker containers..."
docker compose ps

# Command Service の起動
echo "Starting Command Service..."
cd "$PROJECT_ROOT/apps/command_service"
mix run --no-halt > "$PROJECT_ROOT/logs/command_service.log" 2>&1 &
COMMAND_PID=$!
echo "Command Service started with PID: $COMMAND_PID"

# 少し待機
sleep 5

# Query Service の起動
echo "Starting Query Service..."
cd "$PROJECT_ROOT/apps/query_service"
mix run --no-halt > "$PROJECT_ROOT/logs/query_service.log" 2>&1 &
QUERY_PID=$!
echo "Query Service started with PID: $QUERY_PID"

# 少し待機
sleep 5

# Client Service の起動
echo "Starting Client Service..."
cd "$PROJECT_ROOT/apps/client_service"
mix phx.server > "$PROJECT_ROOT/logs/client_service.log" 2>&1 &
CLIENT_PID=$!
echo "Client Service started with PID: $CLIENT_PID"

echo ""
echo "All services started!"
echo "Command Service PID: $COMMAND_PID"
echo "Query Service PID: $QUERY_PID"
echo "Client Service PID: $CLIENT_PID"
echo ""
echo "GraphQL Playground: http://localhost:4000/graphql"
echo "Logs are available in: $PROJECT_ROOT/logs/"
echo ""
echo "Press Ctrl+C to stop all services"

# シグナルハンドラーの設定
trap 'echo "Stopping services..."; kill $COMMAND_PID $QUERY_PID $CLIENT_PID 2>/dev/null; exit' INT TERM

# プロセスの監視
wait