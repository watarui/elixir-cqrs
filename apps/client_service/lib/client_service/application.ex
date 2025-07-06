defmodule ClientService.Application do
  @moduledoc """
  Client Service アプリケーション
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # HTTP エンドポイント
      {Phoenix.PubSub, name: ClientService.PubSub},
      ClientService.Endpoint,

      # gRPC クライアント接続管理
      {ClientService.Infrastructure.GrpcConnections, []}
    ]

    # Supervisor オプション
    opts = [strategy: :one_for_one, name: ClientService.Supervisor]

    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ClientService.Endpoint.config_change(changed, removed)
    :ok
  end
end
