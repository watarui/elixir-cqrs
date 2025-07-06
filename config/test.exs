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
config :query_service, QueryService.Infrastructure.Database.Connection,
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
