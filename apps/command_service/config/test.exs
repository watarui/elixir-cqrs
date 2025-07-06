import Config

# テスト環境用データベース設定
config :command_service, CommandService.Infrastructure.Database.Connection,
  database: "command_service_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# ログレベル設定
config :logger, level: :warn
