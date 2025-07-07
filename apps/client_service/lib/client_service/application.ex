defmodule ClientService.Application do
  @moduledoc """
  Client Service アプリケーション
  """

  use Application

  alias Shared.Telemetry.{Setup, Metrics}

  @impl true
  def start(_type, _args) do
    # OpenTelemetryとTelemetryの初期化
    Setup.setup_opentelemetry()
    Setup.attach_telemetry_handlers()

    # OpenTelemetry Phoenix instrumentation
    OpentelemetryPhoenix.setup()
    OpentelemetryAbsinthe.setup()

    children = [
      # Phoenix PubSub を最初に起動
      {Phoenix.PubSub, name: ClientService.PubSub},
      # Telemetry監視
      {Telemetry.Metrics.ConsoleReporter, metrics: Metrics.metrics()},
      # Prometheusエクスポーター
      {TelemetryMetricsPrometheus,
       metrics: Metrics.prometheus_metrics(), port: 9568},
      # バッチキャッシュ
      ClientService.GraphQL.BatchCache,
      # HTTP エンドポイントを起動
      ClientService.Endpoint,
      # gRPC クライアント接続管理
      {ClientService.Infrastructure.GrpcConnections, []},
      # CQRSファサード
      {ClientService.Application.CqrsFacade, []}
    ]

    # Supervisor オプション
    opts = [strategy: :one_for_one, name: ClientService.Supervisor]

    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ClientService.Endpoint.config_change(changed, removed)
    :ok
  end
end
