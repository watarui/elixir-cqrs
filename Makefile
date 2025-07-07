# Elixir CQRS マイクロサービス Makefile

.PHONY: help build up down logs clean test

# デフォルトターゲット
help:
	@echo "Elixir CQRS マイクロサービス - 利用可能なコマンド:"
	@echo ""
	@echo "Docker 関連:"
	@echo "  make build    - 全サービスのDockerイメージをビルド"
	@echo "  make up       - 全サービスを起動"
	@echo "  make down     - 全サービスを停止"
	@echo "  make logs     - 全サービスのログを表示"
	@echo "  make clean    - 全コンテナとイメージを削除"
	@echo ""
	@echo "開発関連:"
	@echo "  make test     - テストを実行"
	@echo "  make deps     - 依存関係をインストール"
	@echo "  make format   - コードをフォーマット"
	@echo ""
	@echo "個別サービス:"
	@echo "  make up-client    - Client Serviceのみ起動"
	@echo "  make up-command   - Command Serviceのみ起動"
	@echo "  make up-query     - Query Serviceのみ起動"
	@echo "  make up-db        - データベースのみ起動"

# Docker 関連コマンド
build:
	@echo "Dockerイメージをビルド中..."
	docker compose build

up:
	@echo "全サービスを起動中..."
	docker compose up -d --build

down:
	@echo "全サービスを停止中..."
	docker compose down

logs:
	@echo "ログを表示中..."
	docker compose logs -f

clean:
	@echo "全コンテナとイメージを削除中..."
	docker compose down -v --rmi all
	docker system prune -f

# 個別サービス起動
up-client:
	@echo "Client Serviceを起動中..."
	docker compose up -d client-service

up-command:
	@echo "Command Serviceを起動中..."
	docker compose up -d command-service

up-query:
	@echo "Query Serviceを起動中..."
	docker compose up -d query-service

up-db:
	@echo "データベースを起動中..."
	docker compose up -d postgres-command postgres-query

# 開発関連コマンド
test:
	@echo "テストを実行中..."
	mix test

deps:
	@echo "依存関係をインストール中..."
	mix deps.get

format:
	@echo "コードをフォーマット中..."
	mix format

# ヘルスチェック
health:
	@echo "サービスヘルスチェック中..."
	@echo "Client Service:"
	@curl -s http://localhost:4000/health || echo "Client Service が起動していません"
	@echo ""
	@echo "GraphQL API:"
	@curl -s -X POST http://localhost:4000/graphql \
		-H "Content-Type: application/json" \
		-d '{"query": "{ categories { id name } }"}' || echo "GraphQL API が利用できません"

# データベース操作
db-reset:
	@echo "データベースをリセット中..."
	docker compose down -v
	docker compose up -d postgres-command postgres-query
	@sleep 5
	docker compose up -d command-service query-service

# 開発環境セットアップ
setup:
	@echo "開発環境をセットアップ中..."
	make deps
	make build
	make up
	@echo "セットアップ完了！"
	@echo "アクセス先:"
	@echo "  - GraphQL API: http://localhost:4000/graphql"
	@echo "  - ヘルスチェック: http://localhost:4000/health"
	@echo "  - Nginx: http://localhost:80" 