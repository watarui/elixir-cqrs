import Config

# 開発環境の設定

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"


# ホットリロードの設定
config :phoenix, :plug_init_mode, :runtime

# Client Service の開発設定
config :client_service, ClientServiceWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "Jz8VxwqH6K5y5r3NvKcW8P9YQqGtM5TdU3BhX4Y2Zj9KtL3R5N8S4W9X5M2K7P3Q",
  watchers: []

# Enable dev routes for dashboard and mailbox
config :client_service, dev_routes: true

