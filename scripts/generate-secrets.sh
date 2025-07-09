#!/bin/bash

# シークレット生成スクリプト
# 使用方法: ./scripts/generate-secrets.sh [environment]

set -euo pipefail

ENVIRONMENT="${1:-development}"

echo "Generating secrets for environment: $ENVIRONMENT"

# SECRET_KEY_BASE の生成（64文字）
SECRET_KEY_BASE=$(openssl rand -hex 32)

# ENCRYPTION_KEY の生成（32文字）
ENCRYPTION_KEY=$(openssl rand -hex 16)

# DATABASE_PASSWORD の生成
DATABASE_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)

# .env ファイルの生成
cat > ".env.$ENVIRONMENT" <<EOF
# Generated on $(date)
# Environment: $ENVIRONMENT

# データベース設定
DATABASE_HOST=postgres-service
DATABASE_PORT=5432
DATABASE_NAME=event_store
DATABASE_USER=postgres
DATABASE_PASSWORD=$DATABASE_PASSWORD

# アプリケーション設定
MIX_ENV=prod
PORT=4000
PHX_HOST=elixir-cqrs.example.com

# 秘密鍵
SECRET_KEY_BASE=$SECRET_KEY_BASE
ENCRYPTION_KEY=$ENCRYPTION_KEY

# gRPC サービス設定
COMMAND_SERVICE_HOST=command-service
COMMAND_SERVICE_PORT=50051
QUERY_SERVICE_HOST=query-service
QUERY_SERVICE_PORT=50052

# 監視設定
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger-collector:4318
OTEL_SERVICE_NAME=elixir-cqrs
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=$ENVIRONMENT

# プール設定
POOL_SIZE=20
EOF

echo "Secrets generated successfully in .env.$ENVIRONMENT"
echo ""
echo "Next steps:"
echo "1. Review the generated secrets"
echo "2. Store them securely in your secret management system"
echo "3. Never commit .env files to version control"
echo ""
echo "To create Kubernetes secret:"
echo "kubectl create secret generic elixir-cqrs-secrets --from-env-file=.env.$ENVIRONMENT -n elixir-cqrs"