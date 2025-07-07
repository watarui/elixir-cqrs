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
      CommandService.Infrastructure.Database.Repo,

      # イベントストア (PostgreSQL)
      {Shared.Infrastructure.EventStore.PostgresAdapter, []},

      # イベントバス
      {Shared.Infrastructure.EventBus, name: Shared.Infrastructure.EventBus},

      # コマンドバス
      {CommandService.Application.CommandBus, name: CommandService.Application.CommandBus},

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
