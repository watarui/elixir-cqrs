defmodule CommandService.Application do
  @moduledoc """
  Command Service アプリケーション

  書き込み専用のマイクロサービスアプリケーションです
  """

  use Application

  alias Shared.Telemetry.{Metrics, Setup}

  @impl true
  def start(_type, _args) do
    # OpenTelemetryとTelemetryの初期化
    Setup.setup_opentelemetry()
    Setup.attach_telemetry_handlers()

    # OpenTelemetry Ecto instrumentation
    # Docker環境ではモジュールがロードされていない可能性があるため、エラーハンドリングを追加
    if Code.ensure_loaded?(:opentelemetry_ecto) do
      :opentelemetry_ecto.setup([:command_service, :repo])
    end

    base_children = [
      # データベース接続
      CommandService.Infrastructure.Database.Repo,

      # Telemetry監視
      {Telemetry.Metrics.ConsoleReporter, metrics: Metrics.metrics()}
    ]

    # テスト環境ではPrometheusエクスポーターを起動しない
    prometheus_children =
      if Mix.env() != :test do
        [
          {
            TelemetryMetricsPrometheus,
            # Prometheusエクスポーターは内部でPlugを使用するため、
            # 別のPlug.Cowboyは不要
            metrics: Metrics.metrics(), port: 9569, plug_cowboy_opts: []
          }
        ]
      else
        []
      end

    children =
      base_children ++
        prometheus_children ++
        [
          # イベントバス
          {Shared.Infrastructure.EventBus, name: Shared.Infrastructure.EventBus},

          # コマンドバス
          {CommandService.Application.CommandBus, name: CommandService.Application.CommandBus},

          # カテゴリプロジェクション（テスト用）
          CommandService.Infrastructure.Projections.CategoryProjection,

          # サガコーディネーター
          {Shared.Infrastructure.Saga.SagaCoordinator,
           saga_modules: [Shared.Infrastructure.Saga.OrderSaga]},

          # サガイベントハンドラー
          {Shared.Infrastructure.Saga.SagaEventHandler,
           [
             saga_triggers: %{
               "order_created" => Shared.Infrastructure.Saga.OrderSaga
             }
           ]}
        ]

    # テスト環境ではgRPCサーバーを起動しない
    grpc_children =
      if Mix.env() != :test do
        [
          # gRPC サーバー
          {GRPC.Server.Supervisor,
           endpoint: CommandService.Presentation.Grpc.Endpoint, port: 50_051}
        ]
      else
        []
      end

    children = children ++ grpc_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CommandService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
