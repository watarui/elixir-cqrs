.PHONY: help setup deps migrate seed reset test check format docs docker-up docker-down docker-logs

# デフォルトターゲット
help:
	@echo "利用可能なコマンド:"
	@echo "  make setup       - 初期セットアップ（依存関係、DB作成、マイグレーション）"
	@echo "  make deps        - 依存関係のインストール"
	@echo "  make migrate     - データベースマイグレーション"
	@echo "  make seed        - テストデータの投入"
	@echo "  make reset       - データベースのリセット"
	@echo "  make test        - テストの実行"
	@echo "  make check       - コード品質チェック（format, credo, dialyzer）"
	@echo "  make format      - コードフォーマット"
	@echo "  make docs        - ドキュメント生成"
	@echo "  make docker-up   - Docker コンテナ起動"
	@echo "  make docker-down - Docker コンテナ停止"
	@echo "  make docker-logs - Docker ログ表示"

# 初期セットアップ
setup: docker-up deps migrate
	@echo "セットアップ完了！"

# 依存関係のインストール
deps:
	mix deps.get
	mix deps.compile

# データベースマイグレーション
migrate:
	mix ecto.create
	mix ecto.migrate

# テストデータの投入
seed:
	mix run apps/shared/priv/repo/seeds.exs
	mix run apps/command_service/priv/repo/seeds.exs
	mix run apps/query_service/priv/repo/seeds.exs

# データベースのリセット
reset:
	mix ecto.drop
	mix ecto.create
	mix ecto.migrate

# テストの実行
test:
	mix test

# コード品質チェック
check:
	mix format --check-formatted
	mix compile --warnings-as-errors
	mix credo --strict
	mix dialyzer

# コードフォーマット
format:
	mix format

# ドキュメント生成
docs:
	mix docs

# Docker コンテナ起動
docker-up:
	docker compose up -d
	@echo "Docker コンテナが起動しました"
	@echo "Jaeger UI: http://localhost:16686"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000 (admin/admin)"

# Docker コンテナ停止
docker-down:
	docker compose down

# Docker ログ表示
docker-logs:
	docker compose logs -f