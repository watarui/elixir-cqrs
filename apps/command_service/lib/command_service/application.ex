defmodule CommandService.Application do
  @moduledoc """
  Command Service アプリケーション

  書き込み専用のマイクロサービスアプリケーションです
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # データベース接続
      CommandService.Infrastructure.Database.Repo

      # gRPC サーバー (将来実装)
      # {CommandService.Presentation.GrpcServer, port: 50051}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CommandService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
