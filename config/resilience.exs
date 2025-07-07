import Config

# gRPCレジリエンス設定

# リトライ戦略の設定
config :shared, :grpc_retry,
  default: %{
    max_attempts: 3,
    initial_delay: 100,
    max_delay: 5000,
    multiplier: 2.0,
    jitter: true,
    retryable_errors: [:unavailable, :deadline_exceeded, :resource_exhausted, :aborted, :internal]
  },
  # 特定の操作に対するカスタム設定
  operations: %{
    # 読み取り操作は素早くフェイルする
    query: %{
      max_attempts: 2,
      initial_delay: 50,
      max_delay: 1000
    },
    # 書き込み操作はより積極的にリトライ
    command: %{
      max_attempts: 4,
      initial_delay: 200,
      max_delay: 10000
    }
  }

# サーキットブレーカーの設定
config :shared, :circuit_breakers,
  command_service: %{
    failure_threshold: 5,
    success_threshold: 2,
    timeout: 30_000,
    reset_timeout: 60_000
  },
  query_service: %{
    failure_threshold: 5,
    success_threshold: 2,
    timeout: 30_000,
    reset_timeout: 60_000
  }

# タイムアウトの設定
config :shared, :grpc_timeouts,
  default: 5000,
  operations: %{
    # 一覧取得は長めのタイムアウト
    list_products: 10000,
    list_categories: 10000,
    # 単一アイテム取得は短め
    get_product: 3000,
    get_category: 3000,
    # 書き込み操作
    create_product: 5000,
    update_product: 5000,
    delete_product: 5000
  }