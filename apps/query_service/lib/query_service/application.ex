defmodule QueryService.Application do
  @moduledoc """
  Query Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:query_service, :grpc_port, 50_052)

    children = [
      # Ecto リポジトリ
      QueryService.Repo,
      # クエリバス
      QueryService.Infrastructure.QueryBus,
      # プロジェクションマネージャー
      QueryService.Infrastructure.ProjectionManagerV2,
      # TODO: キャッシュ (ETS)
      # gRPC サーバー
      {GRPC.Server.Supervisor,
       endpoint: QueryService.Presentation.Grpc.Endpoint, port: port, start_server: true}
    ]

    opts = [strategy: :one_for_one, name: QueryService.Supervisor]

    require Logger
    Logger.info("Starting Query Service with gRPC server on port #{port}")

    Supervisor.start_link(children, opts)
  end
end
