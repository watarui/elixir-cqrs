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
      # gRPC エンドポイント
      {GRPC.Server.Supervisor, endpoint: CommandService.Presentation.Grpc.Endpoint, port: port}
    ]

    opts = [strategy: :one_for_one, name: CommandService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
