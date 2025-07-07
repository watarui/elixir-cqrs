import Config

# Command Service のテスト環境設定
config :command_service, CommandService.Infrastructure.Database.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "command_service_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Query Service のテスト環境設定
config :query_service, QueryService.Infrastructure.Database.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "query_service_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# gRPC サーバーの設定（テスト環境では自動起動しない）
# start_server オプションは各サービスのSupervisor設定で個別に制御

# Logger の設定
config :logger, level: :warning

# テスト環境では標準のLoggerフォーマッタを使用
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Prometheusエクスポーターはテスト環境では無効化
config :telemetry_metrics_prometheus,
  port: 0  # 0を指定してサーバーを起動しない

# gRPCサーバーはテスト環境では無効化
config :grpc, start_server: false

# イベントストアのテスト環境設定
config :shared, :event_store_repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "event_store_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: 5432
