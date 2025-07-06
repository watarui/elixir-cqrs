import Config

# We don't run a server during test
config :client_service, ClientService.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "client_service_test_secret_key_base_must_be_at_least_64_bytes_long",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# テスト環境用のgRPCサービス設定（モック使用）
config :client_service,
  command_service_host: "localhost",
  command_service_port: 50051,
  query_service_host: "localhost",
  query_service_port: 50052

# GraphQL Playground を無効化
config :client_service, :graphql_playground, enabled: false
