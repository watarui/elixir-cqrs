defmodule QueryService.Application do
  @moduledoc """
  Query Service アプリケーション

  読み取り専用のマイクロサービスアプリケーションです
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
      :opentelemetry_ecto.setup([:query_service, :repo])
    end

    children = [
      # データベース接続
      QueryService.Infrastructure.Database.Repo,

      # Telemetry監視
      {Telemetry.Metrics.ConsoleReporter, metrics: Metrics.metrics()},

      # Prometheusエクスポーター
      {
        TelemetryMetricsPrometheus,
        # Prometheusエクスポーターは内部でPlugを使用するため、
        # 別のPlug.Cowboyは不要
        metrics: Metrics.metrics(), port: 9570, plug_cowboy_opts: []
      },

      # ETSキャッシュ
      QueryService.Infrastructure.Cache.EtsCache,

      # イベントストア (PostgreSQL) - ProjectionManagerがイベントを読むため
      {Shared.Infrastructure.EventStore.PostgresAdapter, []},

      # プロジェクションマネージャー（イベント→Read Model投影）
      {QueryService.Application.ProjectionManager,
       query_repo: QueryService.Infrastructure.Database.Repo},

      # gRPC サーバー
      {GRPC.Server.Supervisor,
       endpoint: QueryService.Presentation.Grpc.Endpoint, port: 50_052, start_server: true}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: QueryService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
