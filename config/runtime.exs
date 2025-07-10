import Config

# ランタイム設定（環境変数から読み込み）
# すべての環境で環境変数を使用可能にする

# データベース共通設定
db_pool_size = String.to_integer(System.get_env("POOL_SIZE") || "10")

# OpenTelemetry 設定
otel_endpoint = System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") || "http://localhost:4318"
otel_service_name = System.get_env("OTEL_SERVICE_NAME") || "elixir-cqrs"

config :opentelemetry_exporter,
  otlp_endpoint: otel_endpoint

config :opentelemetry,
  resource: [
    service: %{
      name: otel_service_name,
      namespace: "cqrs"
    }
  ]

# 環境別のデータベース設定
if config_env() == :prod do
  # 本番環境では DATABASE_URL を必須とする
  event_store_url = System.get_env("EVENT_STORE_DATABASE_URL") ||
    raise """
    environment variable EVENT_STORE_DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

  command_db_url = System.get_env("COMMAND_DATABASE_URL") ||
    raise """
    environment variable COMMAND_DATABASE_URL is missing.
    """

  query_db_url = System.get_env("QUERY_DATABASE_URL") ||
    raise """
    environment variable QUERY_DATABASE_URL is missing.
    """

  config :shared, Shared.Infrastructure.EventStore.Repo,
    url: event_store_url,
    pool_size: db_pool_size

  config :command_service, CommandService.Repo,
    url: command_db_url,
    pool_size: db_pool_size

  config :query_service, QueryService.Repo,
    url: query_db_url,
    pool_size: db_pool_size

  # SECRET_KEY_BASE の検証
  secret_key_base = System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

  if byte_size(secret_key_base) < 64 do
    raise """
    SECRET_KEY_BASE should be at least 64 characters long.
    """
  end

  config :client_service, ClientServiceWeb.Endpoint,
    secret_key_base: secret_key_base,
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000"),
      transport_options: [socket_opts: [:inet6]]
    ],
    url: [host: System.get_env("PHX_HOST") || "example.com", port: 443, scheme: "https"]
else
  # 開発/テスト環境では環境変数を使用するが、デフォルト値を提供
  event_store_config = [
    database: System.get_env("EVENT_STORE_DATABASE") || "elixir_cqrs_event_store_#{config_env()}",
    username: System.get_env("EVENT_STORE_USER") || "postgres",
    password: System.get_env("EVENT_STORE_PASSWORD") || "postgres",
    hostname: System.get_env("EVENT_STORE_HOST") || "localhost",
    port: String.to_integer(System.get_env("EVENT_STORE_PORT") || "5432"),
    pool_size: db_pool_size
  ]

  command_db_config = [
    database: System.get_env("COMMAND_DATABASE") || "elixir_cqrs_command_#{config_env()}",
    username: System.get_env("COMMAND_DB_USER") || "postgres",
    password: System.get_env("COMMAND_DB_PASSWORD") || "postgres",
    hostname: System.get_env("COMMAND_DB_HOST") || "localhost",
    port: String.to_integer(System.get_env("COMMAND_DB_PORT") || "5433"),
    pool_size: db_pool_size
  ]

  query_db_config = [
    database: System.get_env("QUERY_DATABASE") || "elixir_cqrs_query_#{config_env()}",
    username: System.get_env("QUERY_DB_USER") || "postgres",
    password: System.get_env("QUERY_DB_PASSWORD") || "postgres",
    hostname: System.get_env("QUERY_DB_HOST") || "localhost",
    port: String.to_integer(System.get_env("QUERY_DB_PORT") || "5434"),
    pool_size: db_pool_size
  ]

  config :shared, Shared.Infrastructure.EventStore.Repo, event_store_config
  config :command_service, CommandService.Repo, command_db_config
  config :query_service, QueryService.Repo, query_db_config

  # 開発環境の SECRET_KEY_BASE
  # 環境変数が設定されていれば使用、なければ config/dev.exs の値を使用
  if config_env() == :dev && System.get_env("SECRET_KEY_BASE") do
    config :client_service, ClientServiceWeb.Endpoint,
      secret_key_base: System.get_env("SECRET_KEY_BASE")
  end
end
