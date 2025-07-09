import Config

# ランタイム設定（環境変数から読み込み）

if config_env() == :prod do
  # イベントストアのデータベース設定
  database_url = System.get_env("EVENT_STORE_DATABASE_URL") ||
    raise """
    environment variable EVENT_STORE_DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

  config :shared, Shared.Infrastructure.EventStore.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # Command Service のデータベース設定
  command_database_url = System.get_env("COMMAND_DATABASE_URL") ||
    raise """
    environment variable COMMAND_DATABASE_URL is missing.
    """

  config :command_service, CommandService.Repo,
    url: command_database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # Query Service のデータベース設定
  query_database_url = System.get_env("QUERY_DATABASE_URL") ||
    raise """
    environment variable QUERY_DATABASE_URL is missing.
    """

  config :query_service, QueryService.Repo,
    url: query_database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
