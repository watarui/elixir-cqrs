import Config

# Ecto Repository の設定
config :command_service, CommandService.Infrastructure.Database.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_timestamps: [type: :utc_datetime]

# アプリケーション固有の設定
config :command_service, ecto_repos: [CommandService.Infrastructure.Database.Repo]

# Query Service の設定
config :query_service, QueryService.Infrastructure.Database.Connection,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "query_service_db",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# gRPC サーバーの設定
config :grpc, start_server: true
config :query_service, :grpc_port, 50052

# Logger の設定
config :logger,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id]

# 環境別設定ファイルをインポート
import_config "#{config_env()}.exs"
