import Config

# gRPC サービス接続設定（環境変数から読み込み）
config :client_service,
  command_service_host: System.get_env("COMMAND_SERVICE_HOST", "localhost"),
  command_service_port: String.to_integer(System.get_env("COMMAND_SERVICE_PORT", "50051")),
  query_service_host: System.get_env("QUERY_SERVICE_HOST", "localhost"),
  query_service_port: String.to_integer(System.get_env("QUERY_SERVICE_PORT", "50052"))
