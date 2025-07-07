defmodule QueryService.Application do
  @moduledoc """
  Query Service アプリケーション

  読み取り専用のマイクロサービスアプリケーションです
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # データベース接続
      QueryService.Infrastructure.Database.Repo,
      
      # ETSキャッシュ
      QueryService.Infrastructure.Cache.EtsCache,

      # gRPC サーバー
      {GRPC.Server.Supervisor,
       endpoint: QueryService.Presentation.Grpc.Endpoint, port: 50052, start_server: true}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: QueryService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
