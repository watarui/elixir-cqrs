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
      # イベントストアのリポジトリ
      Shared.Infrastructure.EventStore.Repo,
      # イベントバス
      Shared.Infrastructure.EventBus,
      # サガリポジトリ
      Shared.Infrastructure.Saga.SagaRepository,
      # サガコーディネーター
      Shared.Infrastructure.Saga.SagaCoordinator,
      # サガメトリクス
      Shared.Telemetry.SagaMetrics
    ]

    opts = [strategy: :one_for_one, name: Shared.Supervisor]
    Supervisor.start_link(children, opts)
  end
end