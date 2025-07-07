import Config

# Command Service データベース設定
config :command_service, CommandService.Infrastructure.Database.Repo,
  database: "command_service_#{config_env()}",
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

# Shared 設定
config :shared,
  service_name: "command_service",
  command_dispatcher: CommandService.Infrastructure.SagaCommandDispatcher

# 環境別設定の読み込み
import_config "#{config_env()}.exs"
