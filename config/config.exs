# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Logger の設定
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id]

# OpenTelemetry の設定
config :opentelemetry,
  resource: [
    service: %{
      name: "elixir-cqrs",
      namespace: "cqrs"
    }
  ],
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318",
  otlp_headers: [],
  otlp_compression: :gzip

# Jason の設定
config :phoenix, :json_library, Jason

# イベントストアの設定
config :shared, Shared.Infrastructure.EventStore.Repo,
  database: "elixir_cqrs_event_store_#{config_env()}",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10

config :shared,
  ecto_repos: [Shared.Infrastructure.EventStore.Repo],
  event_store_adapter: Shared.Infrastructure.EventStore.PostgresAdapter

# Command Service の設定
config :command_service,
  ecto_repos: [CommandService.Repo],
  grpc_port: 50051

config :command_service, CommandService.Repo,
  database: "elixir_cqrs_command_#{config_env()}",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10

# Query Service の設定
config :query_service,
  ecto_repos: [QueryService.Repo],
  grpc_port: 50052

config :query_service, QueryService.Repo,
  database: "elixir_cqrs_query_#{config_env()}",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10

# gRPC の設定
config :grpc, start_server: true

# Client Service の設定
config :client_service,
  command_service_host: "localhost",
  query_service_host: "localhost"

config :client_service, ClientServiceWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: ClientServiceWeb.ErrorHTML, json: ClientServiceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ClientService.PubSub,
  live_view: [signing_salt: "7K9BfGu5"]


# 環境別の設定をインポート
import_config "#{config_env()}.exs"