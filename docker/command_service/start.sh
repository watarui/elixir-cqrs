#!/bin/sh

# Command Service 起動スクリプト

echo "Starting Command Service..."

# データベースの準備
echo "Setting up database..."
cd apps/command_service || exit

# データベースが存在しない場合は作成
mix ecto.create || true

# マイグレーション実行
mix ecto.migrate

# シードデータ投入
mix run priv/repo/seeds.exs

# アプリケーション起動
echo "Starting Command Service on port 50051..."
mix run --no-halt
