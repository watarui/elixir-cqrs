# 環境変数設定ガイド

このドキュメントでは、elixir-cqrs プロジェクトで使用する環境変数について説明します。

## 概要

本プロジェクトは環境変数を使用して設定を管理しています。これにより、環境ごとに異なる設定を安全に管理できます。

## 環境変数の設定方法

### 開発環境

1. `.env.example` をコピーして `.env` を作成

```bash
cp .env.example .env
```

2. 必要に応じて値を編集

```bash
vi .env
```

3. アプリケーション起動時に自動的に読み込まれます

### 本番環境

本番環境では、以下のいずれかの方法で環境変数を設定します：

- **Kubernetes Secrets**
- **AWS Secrets Manager**
- **GitHub Secrets** (CI/CD)
- **環境変数として直接設定**

## 環境変数一覧

### データベース設定

#### Event Store

| 変数名                     | 説明                   | デフォルト値                | 必須     |
| -------------------------- | ---------------------- | --------------------------- | -------- |
| `EVENT_STORE_HOST`         | ホスト名               | localhost                   | 開発環境 |
| `EVENT_STORE_PORT`         | ポート番号             | 5432                        | 開発環境 |
| `EVENT_STORE_DATABASE`     | データベース名         | elixir_cqrs_event_store_dev | 開発環境 |
| `EVENT_STORE_USER`         | ユーザー名             | postgres                    | 開発環境 |
| `EVENT_STORE_PASSWORD`     | パスワード             | postgres                    | 開発環境 |
| `EVENT_STORE_DATABASE_URL` | 接続 URL（本番環境用） | -                           | 本番環境 |

#### Command Service

| 変数名                 | 説明                   | デフォルト値            | 必須     |
| ---------------------- | ---------------------- | ----------------------- | -------- |
| `COMMAND_DB_HOST`      | ホスト名               | localhost               | 開発環境 |
| `COMMAND_DB_PORT`      | ポート番号             | 5433                    | 開発環境 |
| `COMMAND_DATABASE`     | データベース名         | elixir_cqrs_command_dev | 開発環境 |
| `COMMAND_DB_USER`      | ユーザー名             | postgres                | 開発環境 |
| `COMMAND_DB_PASSWORD`  | パスワード             | postgres                | 開発環境 |
| `COMMAND_DATABASE_URL` | 接続 URL（本番環境用） | -                       | 本番環境 |

#### Query Service

| 変数名               | 説明                   | デフォルト値          | 必須     |
| -------------------- | ---------------------- | --------------------- | -------- |
| `QUERY_DB_HOST`      | ホスト名               | localhost             | 開発環境 |
| `QUERY_DB_PORT`      | ポート番号             | 5434                  | 開発環境 |
| `QUERY_DATABASE`     | データベース名         | elixir_cqrs_query_dev | 開発環境 |
| `QUERY_DB_USER`      | ユーザー名             | postgres              | 開発環境 |
| `QUERY_DB_PASSWORD`  | パスワード             | postgres              | 開発環境 |
| `QUERY_DATABASE_URL` | 接続 URL（本番環境用） | -                     | 本番環境 |

### アプリケーション設定

| 変数名            | 説明                          | デフォルト値 | 必須     |
| ----------------- | ----------------------------- | ------------ | -------- |
| `MIX_ENV`         | Elixir 環境                   | dev          | ○        |
| `PORT`            | HTTP ポート                   | 4000         | ○        |
| `PHX_HOST`        | Phoenix ホスト名              | localhost    | ○        |
| `SECRET_KEY_BASE` | セッションキー（64 文字以上） | -            | 本番環境 |
| `ENCRYPTION_KEY`  | 暗号化キー                    | -            | △        |

### 分散システム設定

| 変数名        | 説明            | デフォルト値       | 必須 |
| ------------- | --------------- | ------------------ | ---- |
| `NODE_NAME`   | Erlang ノード名 | client@127.0.0.1   | △    |
| `NODE_COOKIE` | Erlang クッキー | elixir_cqrs_secret | △    |

### 監視・オブザーバビリティ

| 変数名                        | 説明                         | デフォルト値                       | 必須 |
| ----------------------------- | ---------------------------- | ---------------------------------- | ---- |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OpenTelemetry エンドポイント | http://localhost:4318              | △    |
| `OTEL_SERVICE_NAME`           | サービス名                   | elixir-cqrs                        | △    |
| `OTEL_RESOURCE_ATTRIBUTES`    | リソース属性                 | deployment.environment=development | △    |

### その他の設定

| 変数名       | 説明                 | デフォルト値 | 必須 |
| ------------ | -------------------- | ------------ | ---- |
| `POOL_SIZE`  | DB 接続プールサイズ  | 10           | △    |
| `LOG_LEVEL`  | ログレベル           | debug        | △    |
| `PHX_SERVER` | Phoenix サーバー起動 | true         | △    |

## セキュリティのベストプラクティス

### 1. シークレットの生成

```bash
# SECRET_KEY_BASE の生成
mix phx.gen.secret

# ランダムなパスワードの生成
openssl rand -base64 32
```

### 2. 本番環境での管理

- 環境変数を直接コミットしない
- `.env` ファイルを `.gitignore` に追加
- シークレット管理サービスを使用

### 3. Kubernetes での使用例

```bash
# シークレットの作成
kubectl create secret generic elixir-cqrs-secrets \
  --from-env-file=.env.production \
  -n elixir-cqrs
```

### 4. Docker Compose での使用例

```yaml
services:
  app:
    env_file:
      - .env
    environment:
      - MIX_ENV=prod
```

## トラブルシューティング

### 環境変数が読み込まれない場合

1. 環境変数が正しく設定されているか確認

```bash
echo $EVENT_STORE_DATABASE_URL
```

2. runtime.exs が正しく読み込まれているか確認

```bash
mix run -e "IO.inspect(Application.get_env(:shared, Shared.Infrastructure.EventStore.Repo))"
```

環境変数やデータベース接続の詳細なトラブルシューティングについては [TROUBLESHOOTING.md](TROUBLESHOOTING.md#データベース関連) を参照してください。

## 環境別の設定例

### 開発環境 (.env.development)

```bash
MIX_ENV=dev
EVENT_STORE_HOST=localhost
EVENT_STORE_PORT=5432
LOG_LEVEL=debug
```

### ステージング環境 (.env.staging)

```bash
MIX_ENV=prod
EVENT_STORE_DATABASE_URL=ecto://user:pass@staging-db:5432/event_store
LOG_LEVEL=info
SECRET_KEY_BASE=<64文字以上のランダム文字列>
```

### 本番環境 (.env.production)

```bash
MIX_ENV=prod
EVENT_STORE_DATABASE_URL=${DATABASE_URL}
LOG_LEVEL=warn
SECRET_KEY_BASE=${SECRET_KEY_BASE}
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-collector.example.com:4318
```
