defmodule CommandService.Application do
  @moduledoc """
  Command Service アプリケーション

  書き込み専用のマイクロサービスアプリケーションです
  """

  use Application

  @impl true
  def start(_type, _args) do
    # OpenTelemetryとTelemetryの初期化
    Shared.Telemetry.Setup.setup_opentelemetry()
    Shared.Telemetry.Setup.attach_telemetry_handlers()
    
    # OpenTelemetry Ecto instrumentation
    :opentelemetry_ecto.setup([:command_service, :repo])
    
    children = [
      # データベース接続
      CommandService.Infrastructure.Database.Repo,

      # Telemetry監視
      {Telemetry.Metrics.ConsoleReporter, metrics: Shared.Telemetry.Metrics.metrics()},

      # イベントストア (PostgreSQL)
      {Shared.Infrastructure.EventStore.PostgresAdapter, []},

      # イベントバス
      {Shared.Infrastructure.EventBus, name: Shared.Infrastructure.EventBus},

      # コマンドバス
      {CommandService.Application.CommandBus, name: CommandService.Application.CommandBus},
      
      # サガコーディネーター
      {Shared.Infrastructure.Saga.SagaCoordinator, 
       saga_modules: [CommandService.Domain.Sagas.OrderSaga]},
      
      # サガイベントハンドラー
      {Shared.Infrastructure.Saga.SagaEventHandler, []},

      # gRPC サーバー
      {GRPC.Server.Supervisor,
       endpoint: CommandService.Presentation.Grpc.Endpoint, port: 50051, start_server: true}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CommandService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
