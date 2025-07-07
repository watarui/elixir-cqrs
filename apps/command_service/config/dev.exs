import Config

# 開発環境用データベース設定
config :command_service, CommandService.Infrastructure.Database.Repo,
  database: "command_service_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# ログレベル設定
config :logger, level: :debug
