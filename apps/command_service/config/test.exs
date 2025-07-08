import Config

# テスト環境用データベース設定
config :command_service, CommandService.Infrastructure.Database.Connection,
  database: "command_service_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# ログレベル設定
config :logger, level: :warn

# イベントストア設定
config :shared, :event_store_adapter, Shared.Infrastructure.EventStore.PostgresAdapter

config :shared, Shared.Infrastructure.EventStore.PostgresAdapter,
  database: "event_store_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: System.get_env("DATABASE_USER", "postgres"),
  password: System.get_env("DATABASE_PASSWORD", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: String.to_integer(System.get_env("DATABASE_PORT", "5432")),
  pool_size: 10
