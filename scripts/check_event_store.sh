#!/bin/bash

echo "=== イベントストアのテーブル確認 ==="

# イベントストアDBに接続してテーブルを確認
echo "1. テーブル一覧:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "\dt"

echo -e "\n2. eventsテーブルの構造:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "\d events"

echo -e "\n3. 保存されているイベント数:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "SELECT COUNT(*) FROM events;"

echo -e "\n4. 最新10件のイベント:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "SELECT position, stream_name, event_type, occurred_at FROM events ORDER BY position DESC LIMIT 10;"

echo -e "\n5. ストリーム別のイベント数:"
docker exec -it elixir-cqrs-postgres-event psql -U postgres -d event_store -c "SELECT stream_name, COUNT(*) as event_count FROM events GROUP BY stream_name;"