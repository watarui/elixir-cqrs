#!/bin/sh

# Query Service 起動スクリプト

echo "Starting Query Service..."

# データベースの準備
echo "Setting up database..."
cd apps/query_service || exit

# データベースが存在しない場合は作成
mix ecto.create || true

# マイグレーション実行
mix ecto.migrate

# シードデータ投入
mix run priv/repo/seeds.exs

# アプリケーション起動
echo "Starting Query Service on port 50052..."
mix run --no-halt
