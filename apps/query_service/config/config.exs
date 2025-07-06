import Config

# Query Service データベース設定（読み取り専用）
config :query_service, QueryService.Infrastructure.Database.Connection,
  database: "query_service_#{config_env()}",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  pool_timeout: 5000,
  timeout: 15000

# ログ設定
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# 環境別設定の読み込み
import_config "#{config_env()}.exs"
