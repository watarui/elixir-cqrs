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

    base_children = [
      # データベース接続
      QueryService.Infrastructure.Database.Repo,

      # Telemetry監視
      {Telemetry.Metrics.ConsoleReporter, metrics: Metrics.metrics()},

      # ETSキャッシュ
      QueryService.Infrastructure.Cache.EtsCache,

      # プロジェクションマネージャー（イベント→Read Model投影）
      # イベントストアはsharedアプリケーションで起動されているため、ここでは起動しない
      {QueryService.Application.ProjectionManager,
       query_repo: QueryService.Infrastructure.Database.Repo}
    ]

    # Prometheusエクスポーターとgはは本番環境でのみ起動
    children =
      if Mix.env() != :test do
        base_children ++
          [
            {
              TelemetryMetricsPrometheus,
              metrics: Metrics.metrics(), port: 9570, plug_cowboy_opts: []
            },
            # gRPC サーバー
            {GRPC.Server.Supervisor,
             endpoint: QueryService.Presentation.Grpc.Endpoint, port: 50_052}
          ]
      else
        base_children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: QueryService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
