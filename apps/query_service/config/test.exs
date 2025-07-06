import Config

# テスト環境用データベース設定（読み取り専用）
config :query_service, QueryService.Infrastructure.Database.Connection,
  database: "query_service_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# ログレベル設定
config :logger, level: :warn
