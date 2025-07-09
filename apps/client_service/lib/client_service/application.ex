defmodule ClientService.Application do
  @moduledoc """
  Client Service アプリケーション
  
  GraphQL API ゲートウェイとして機能します
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Telemetry
      ClientServiceWeb.Telemetry,
      # PubSub
      {Phoenix.PubSub, name: ClientService.PubSub},
      # Endpoint
      ClientServiceWeb.Endpoint,
      # gRPC 接続プール
      {ClientService.Infrastructure.GrpcConnections, []}
    ]

    opts = [strategy: :one_for_one, name: ClientService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ClientServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end