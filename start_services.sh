#!/bin/bash

# サービス起動スクリプト

echo "Starting CQRS/ES/SAGA Microservices..."

# Docker が起動していることを確認
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Please start Docker first."
    exit 1
fi

# Docker コンテナを起動
echo "Starting Docker containers..."
docker compose up -d

# 少し待つ
echo "Waiting for services to be ready..."
sleep 5

# 依存関係を取得
echo "Installing dependencies..."
mix deps.get

# データベースをセットアップ
echo "Setting up databases..."
mix ecto.create
mix ecto.migrate

echo ""
echo "All services started!"
echo ""
echo "Access URLs:"
echo "  GraphQL Playground: http://localhost:4000/graphiql"
echo "  Jaeger UI:         http://localhost:16686"
echo "  Prometheus:        http://localhost:9090"
echo "  Grafana:           http://localhost:3000 (admin/admin)"
echo ""
echo "To start the services, run:"
echo "  iex -S mix"
echo ""
echo "Or start services individually:"
echo "  cd apps/command_service && iex -S mix"
echo "  cd apps/query_service && iex -S mix"
echo "  cd apps/client_service && iex -S mix phx.server"