import Config

# 開発環境の設定

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# ホットリロードの設定
config :phoenix, :plug_init_mode, :runtime