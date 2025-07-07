import Config

# 本番環境での実行時設定
if config_env() == :prod do
  # Client Service設定
  if Code.ensure_loaded?(ClientService) do
    database_url =
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """

    config :client_service, ClientService.Repo,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

    secret_key_base =
      System.get_env("SECRET_KEY_BASE") ||
        raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """

    config :client_service, ClientService.Endpoint,
      http: [
        port: String.to_integer(System.get_env("PORT") || "4000"),
        transport_options: [socket_opts: [:inet6]]
      ],
      secret_key_base: secret_key_base,
      server: true

    # gRPC接続設定
    config :client_service,
      command_service_host: System.get_env("COMMAND_SERVICE_HOST") || "localhost",
      command_service_port: String.to_integer(System.get_env("COMMAND_SERVICE_PORT") || "50051"),
      query_service_host: System.get_env("QUERY_SERVICE_HOST") || "localhost",
      query_service_port: String.to_integer(System.get_env("QUERY_SERVICE_PORT") || "50052")
  end

  # Command Service設定
  if Code.ensure_loaded?(CommandService) do
    database_url =
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        """

    config :command_service, CommandService.Repo,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

    # イベントストア設定
    event_store_url = System.get_env("EVENT_STORE_URL") || database_url

    config :command_service,
      event_store_url: event_store_url,
      grpc_port: String.to_integer(System.get_env("PORT") || "50051")
  end

  # Query Service設定
  if Code.ensure_loaded?(QueryService) do
    database_url =
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        """

    config :query_service, QueryService.Repo,
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

    # イベントストア設定（読み取り専用）
    event_store_url = System.get_env("EVENT_STORE_URL") || database_url

    config :query_service,
      event_store_url: event_store_url,
      grpc_port: String.to_integer(System.get_env("PORT") || "50052")
  end

  # OpenTelemetry設定
  config :opentelemetry,
    span_processor: :batch,
    traces_exporter: :otlp

  config :opentelemetry_exporter,
    otlp_protocol: :http_protobuf,
    otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") || "http://localhost:4317"

  # Logger設定
  config :logger, :default_formatter,
    format: "$time $metadata[$level] $message\n",
    metadata: [:request_id, :trace_id, :span_id]

  config :logger, level: :info
end