import Config

# 本番環境の設定
# 実際の設定値は環境変数から取得するため、runtime.exsで行う

# ログレベルの設定
config :logger, level: :info

# 本番環境ではconsoleバックエンドのみ使用
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id]

# OpenTelemetryの本番設定
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

# 各アプリケーションの基本設定
# 実際の接続情報等は環境変数から取得（runtime.exs）

# Command Service
config :command_service,
  env: :prod

# Query Service  
config :query_service,
  env: :prod

# Client Service
config :client_service,
  env: :prod

# Phoenix関連の設定（Client Service用）
config :client_service, ClientService.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# その他の本番環境設定はruntime.exsで環境変数から読み込む