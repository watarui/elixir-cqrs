defmodule Shared.Application do
  @moduledoc """
  Shared アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    # OpenTelemetry を初期化
    Shared.Telemetry.Setup.init()

    children = [
      # HTTPクライアント
      {Finch, name: Shared.Finch},
      # イベントストアのリポジトリ
      Shared.Infrastructure.EventStore.Repo,
      # イベントバス
      Shared.Infrastructure.EventBus,
      # アグリゲートバージョンキャッシュ
      Shared.Infrastructure.EventStore.AggregateVersionCache,
      # サーキットブレーカー
      Shared.Infrastructure.Resilience.CircuitBreakerSupervisor,
      # デッドレターキュー
      Shared.Infrastructure.DeadLetterQueue,
      # べき等性ストア
      Shared.Infrastructure.Idempotency.IdempotencyStore,
      # サービスディスカバリ
      Shared.Infrastructure.ServiceDiscovery.ServiceRegistry,
      Shared.Infrastructure.ServiceDiscovery.ServiceRegistrar,
      # Sagaコンポーネント
      Shared.Infrastructure.Saga.SagaLockManager,
      Shared.Infrastructure.Saga.SagaTimeoutManager,
      Shared.Infrastructure.Saga.SagaExecutor,
      Shared.Infrastructure.Saga.SagaMonitor,
      # サガメトリクス
      Shared.Telemetry.SagaMetrics
    ]

    opts = [strategy: :one_for_one, name: Shared.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
