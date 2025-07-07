import Config

# Ecto Repository の設定
config :command_service, CommandService.Infrastructure.Database.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_timestamps: [type: :utc_datetime]

# アプリケーション固有の設定
config :command_service, ecto_repos: [CommandService.Infrastructure.Database.Repo]
config :query_service, ecto_repos: [QueryService.Infrastructure.Database.Repo]

# Query Service の設定
config :query_service, QueryService.Infrastructure.Database.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "query_service_dev",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# gRPC サーバーの設定
config :query_service, :grpc_port, 50052

# 構造化ログの設定
config :logger, :console,
  format: {LoggerJSON.Formatters.Basic, []}

config :logger,
  backends: [:console],
  level: :info

# OpenTelemetryの設定
config :opentelemetry,
  resource: %{
    service: %{
      name: "elixir-cqrs",
      version: "0.1.0"
    }
  },
  span_processor: :batch,
  traces_exporter: :otlp

# Jaegerエクスポーターの設定
config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://localhost:4317",
  otlp_compression: :gzip

# サンプリング設定
config :opentelemetry, :processors,
  otel_batch_processor: %{
    exporter: {:opentelemetry_exporter, %{}}
  }

# Saga設定
config :shared,
  command_dispatcher: CommandService.Infrastructure.SagaCommandDispatcher

# レジリエンス設定をインポート
import_config "resilience.exs"

# 環境別設定ファイルをインポート
import_config "#{config_env()}.exs"
