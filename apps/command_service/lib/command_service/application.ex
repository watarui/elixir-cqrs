defmodule CommandService.Application do
  @moduledoc """
  Command Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:command_service, :grpc_port, 50051)
    
    children = [
      # gRPC エンドポイント
      {GRPC.Server.Supervisor, endpoint: CommandService.Presentation.Grpc.Endpoint, port: port, start_server: true}
    ]

    opts = [strategy: :one_for_one, name: CommandService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end