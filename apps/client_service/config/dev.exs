import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :client_service, ClientService.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "client_service_dev_secret_key_base_must_be_at_least_64_bytes_long",
  watchers: []

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# GraphQL Playground の有効化
config :client_service, :graphql_playground, enabled: true

# 開発環境用のgRPCサービス設定
config :client_service,
  command_service_host: "localhost",
  command_service_port: 50051,
  query_service_host: "localhost",
  query_service_port: 50052
