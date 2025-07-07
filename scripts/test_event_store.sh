#!/bin/bash

echo "=== イベントストアのテスト ==="

# イベントストアのデータベースに接続できるか確認
echo "1. データベース接続テスト:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "SELECT current_database(), version();" || {
    echo "Error: イベントストアデータベースに接続できません"
    exit 1
}

# テーブルが存在するか確認
echo -e "\n2. テーブル存在確認:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public';"

# eventsテーブルの構造を確認
echo -e "\n3. eventsテーブルの詳細構造:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "\d+ events" 2>/dev/null || {
    echo "eventsテーブルが存在しません。テーブルを作成する必要があります。"
}

# インデックスの確認
echo -e "\n4. インデックス一覧:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "\di"

# 権限の確認
echo -e "\n5. テーブル権限:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "\dp events" 2>/dev/null || echo "eventsテーブルが存在しません"