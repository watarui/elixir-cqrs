import Config

# 開発環境用データベース設定（読み取り専用）
config :query_service, QueryService.Infrastructure.Database.Connection,
  database: "query_service_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# ログレベル設定
config :logger, level: :debug
