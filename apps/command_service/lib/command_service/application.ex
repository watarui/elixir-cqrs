defmodule CommandService.Application do
  @moduledoc """
  Command Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:command_service, :grpc_port, 50_051)

    children = [
      # Ecto リポジトリ
      CommandService.Repo,
      # コマンドバス
      CommandService.Infrastructure.CommandBus,
      # gRPC サーバー
      {GRPC.Server.Supervisor, 
        endpoint: CommandService.Presentation.Grpc.Endpoint, 
        port: port,
        start_server: true}
    ]

    opts = [strategy: :one_for_one, name: CommandService.Supervisor]

    require Logger
    Logger.info("Starting Command Service with gRPC server on port #{port}")

    Supervisor.start_link(children, opts)
  end
end
