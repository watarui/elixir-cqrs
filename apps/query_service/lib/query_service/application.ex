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
      QueryService.Infrastructure.Database.Connection

      # gRPC サーバー (将来実装)
      # {QueryService.Presentation.GrpcServer, port: 50052}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: QueryService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
