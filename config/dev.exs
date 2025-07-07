import Config

# イベントストアの設定
config :shared,
  event_store_adapter: Shared.Infrastructure.EventStore.PostgresAdapter

# Development環境でのデータベース設定
config :command_service, CommandService.Infrastructure.Database.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "command_service_dev",
  port: 5432,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Query Service の開発環境設定
config :query_service, QueryService.Infrastructure.Database.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "query_service_dev",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# gRPC サーバーのポート設定
config :command_service, :grpc_port, 50051
config :query_service, :grpc_port, 50052

# Logger の詳細ログを有効化
config :logger, level: :debug

# Ecto クエリのログを有効化
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :module],
  level: :debug

# Stack trace の設定
config :phoenix, :stacktrace_depth, 20

# 開発環境用の設定
config :phoenix, :plug_init_mode, :runtime
