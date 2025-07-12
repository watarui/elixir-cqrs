defmodule ClientService.Application do
  @moduledoc """
  Client Service アプリケーション

  GraphQL API ゲートウェイとして機能します
  """

  use Application

  @impl true
  def start(_type, _args) do
    # クラスタリングの初期化
    connect_to_cluster()

    children = [
      # Telemetry
      ClientServiceWeb.Telemetry,
      # PubSub
      {Phoenix.PubSub, name: ClientService.PubSub},
      # Remote Command Bus (PubSub経由でコマンドを送信)
      ClientService.Infrastructure.RemoteCommandBus,
      # Remote Query Bus (PubSub経由でクエリを送信)
      ClientService.Infrastructure.RemoteQueryBus,
      # PubSub Broadcaster (リアルタイムモニタリング用)
      ClientService.PubSubBroadcaster,
      # Endpoint
      ClientServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ClientService.Supervisor]

    require Logger
    Logger.info("Starting Client Service with GraphQL API on node: #{node()}")

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ClientServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp connect_to_cluster do
    require Logger

    # 他のノードに接続を試みる
    nodes = [:"command@127.0.0.1", :"query@127.0.0.1"]

    Enum.each(nodes, fn node ->
      case Node.connect(node) do
        true ->
          Logger.info("Connected to node: #{node}")

        false ->
          Logger.debug("Could not connect to node: #{node} (may not be started yet)")

        :ignored ->
          Logger.debug("Connection to node #{node} was ignored")
      end
    end)

    Logger.info("Current connected nodes: #{inspect(Node.list())}")
  end
end
