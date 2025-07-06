import Config

# General application configuration
config :client_service,
  ecto_repos: []

# Configures the endpoint
config :client_service, ClientService.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: ClientService.ErrorJSON],
    layout: false
  ],
  pubsub_server: ClientService.PubSub,
  live_view: [signing_salt: "client_live_view_salt"]

# gRPC サービス接続設定
config :client_service,
  command_service_host: System.get_env("COMMAND_SERVICE_HOST", "localhost"),
  command_service_port: String.to_integer(System.get_env("COMMAND_SERVICE_PORT", "50051")),
  query_service_host: System.get_env("QUERY_SERVICE_HOST", "localhost"),
  query_service_port: String.to_integer(System.get_env("QUERY_SERVICE_PORT", "50052"))

# GraphQL 設定
config :absinthe, Absinthe.Logger, filter: true

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config
import_config "#{config_env()}.exs"
