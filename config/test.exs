import Config

# Check if DATABASE_URL is set (for CI environments)
database_url = System.get_env("DATABASE_URL")

if database_url do
  # Parse DATABASE_URL for CI environment
  config :command_service, CommandService.Infrastructure.Database.Repo,
    url: database_url,
    database: "command_service_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10

  config :query_service, QueryService.Infrastructure.Database.Repo,
    url: database_url,
    database: "query_service_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
else
  # Local test environment
  config :command_service, CommandService.Infrastructure.Database.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "command_service_test#{System.get_env("MIX_TEST_PARTITION")}",
    port: 5432,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10

  config :query_service, QueryService.Infrastructure.Database.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "query_service_test#{System.get_env("MIX_TEST_PARTITION")}",
    port: 5432,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end

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
if database_url do
  # CI環境ではDATABASE_URLから設定を取得
  config :shared, :event_store_repo,
    url: database_url,
    database: "event_store_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool_size: 10
else
  # ローカル環境では明示的な設定を使用
  config :shared, :event_store_repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "event_store_test#{System.get_env("MIX_TEST_PARTITION")}",
    port: 5432
end

# Shared application configuration
config :shared,
  command_dispatcher: Shared.Infrastructure.Saga.TestCommandDispatcher,
  event_store_adapter: Shared.Infrastructure.EventStore.PostgresAdapter

# Configure shared database
if database_url do
  config :shared, Shared.Infrastructure.Database.Repo,
    url: database_url,
    database: "shared_test#{System.get_env("MIX_TEST_PARTITION")}",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
else
  config :shared, Shared.Infrastructure.Database.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    database: "shared_test#{System.get_env("MIX_TEST_PARTITION")}",
    port: 5432,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10
end

# Disable async processing in tests
config :shared, :async_processing, false

# Use test implementation for command bus
config :command_service, :command_bus_enabled, false

# Use test implementation for event bus
config :shared, :event_bus_enabled, false

# Client service endpoint configuration
config :client_service, ClientService.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_value_that_is_at_least_64_bytes_long_for_testing",
  server: false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
