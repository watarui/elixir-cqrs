.PHONY: all deps proto setup-db start-command start-query start-client stop clean test

# デフォルトターゲット
all: deps proto setup-db

# 依存関係のインストール
deps:
	@echo "Installing dependencies..."
	@mix deps.get
	@cd apps/command_service && mix deps.get
	@cd apps/query_service && mix deps.get
	@cd apps/client_service && mix deps.get

# Proto ファイルのコンパイル
proto:
	@echo "Compiling proto files..."
	@./scripts/generate_proto.sh

# データベースのセットアップ
setup-db:
	@echo "Setting up databases..."
	@docker compose up -d postgres-event-store postgres-command postgres-query
	@sleep 5
	@./scripts/setup_databases.sh

# Command Service の起動
start-command:
	@echo "Starting Command Service..."
	@cd apps/command_service && MIX_ENV=dev mix run --no-halt

# Query Service の起動
start-query:
	@echo "Starting Query Service..."
	@cd apps/query_service && MIX_ENV=dev mix run --no-halt

# Client Service の起動
start-client:
	@echo "Starting Client Service..."
	@cd apps/client_service && MIX_ENV=dev mix phx.server

# Docker コンテナの停止
stop:
	@echo "Stopping all services..."
	@docker compose down

# クリーンアップ
clean:
	@echo "Cleaning up..."
	@rm -rf _build deps
	@cd apps/command_service && rm -rf _build deps
	@cd apps/query_service && rm -rf _build deps
	@cd apps/client_service && rm -rf _build deps

# テスト実行
test:
	@echo "Running tests..."
	@mix test

# データベースの再作成
reset-db:
	@echo "Resetting databases..."
	@docker compose down -v
	@docker compose up -d postgres-event-store postgres-command postgres-query
	@sleep 5
	@./scripts/setup_databases.sh

# ログ確認
logs-command:
	@docker compose logs -f command_service

logs-query:
	@docker compose logs -f query_service

logs-client:
	@docker compose logs -f client_service

logs-db:
	@docker compose logs -f postgres-event-store postgres-command postgres-query

# ヘルプ
help:
	@echo "Available targets:"
	@echo "  make deps          - Install all dependencies"
	@echo "  make proto         - Compile proto files"
	@echo "  make setup-db      - Setup databases"
	@echo "  make start-command - Start Command Service"
	@echo "  make start-query   - Start Query Service"
	@echo "  make start-client  - Start Client Service"
	@echo "  make stop          - Stop all services"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make test          - Run tests"
	@echo "  make reset-db      - Reset databases"
	@echo "  make logs-command  - Show Command Service logs"
	@echo "  make logs-query    - Show Query Service logs"
	@echo "  make logs-client   - Show Client Service logs"
	@echo "  make logs-db       - Show database logs"