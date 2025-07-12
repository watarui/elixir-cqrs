defmodule Shared.Infrastructure.ServiceDiscovery.ServiceRegistrar do
  @moduledoc """
  サービスの自動登録を管理するモジュール

  アプリケーション起動時にサービスを自動登録し、
  シャットダウン時に登録解除を行う。
  """

  use GenServer

  alias Shared.Infrastructure.ServiceDiscovery.ServiceRegistry

  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  サービスを自動登録する

  アプリケーションの設定から情報を読み取り登録
  """
  @spec auto_register() :: :ok
  def auto_register do
    GenServer.call(__MODULE__, :auto_register)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # 自動登録が有効な場合は起動時に登録
    if Keyword.get(opts, :auto_register, true) do
      send(self(), :register_services)
    end

    # プロセスが終了する際に登録解除するようトラップ
    Process.flag(:trap_exit, true)

    state = %{
      registered_services: [],
      config: opts
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:auto_register, _from, state) do
    new_state = register_configured_services(state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:register_services, state) do
    new_state = register_configured_services(state)
    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    # 登録したすべてのサービスを解除
    Enum.each(state.registered_services, fn {name, instance_id} ->
      Logger.info("Deregistering service #{name} (#{instance_id}) on shutdown")
      ServiceRegistry.deregister(name, instance_id)
    end)

    :ok
  end

  # Private functions

  defp register_configured_services(state) do
    # アプリケーション設定からサービス情報を取得
    services = get_service_configs()

    registered =
      Enum.map(services, fn service_config ->
        register_service(service_config)
      end)
      |> Enum.filter(&(&1 != nil))

    %{state | registered_services: registered}
  end

  defp get_service_configs do
    # 各アプリケーションのサービス設定を取得
    [
      get_command_service_config(),
      get_query_service_config(),
      get_client_service_config()
    ]
    |> Enum.filter(&(&1 != nil))
  end

  defp get_command_service_config do
    if Code.ensure_loaded?(CommandService) do
      %{
        name: "command-service",
        host: System.get_env("COMMAND_SERVICE_HOST", "localhost"),
        port: String.to_integer(System.get_env("COMMAND_SERVICE_PORT", "4001")),
        metadata: %{
          version: "1.0.0",
          capabilities: ["order", "product", "category"]
        },
        # デフォルトの/healthを使用
        health_check_url: nil
      }
    end
  end

  defp get_query_service_config do
    if Code.ensure_loaded?(QueryService) do
      %{
        name: "query-service",
        host: System.get_env("QUERY_SERVICE_HOST", "localhost"),
        port: String.to_integer(System.get_env("QUERY_SERVICE_PORT", "4002")),
        metadata: %{
          version: "1.0.0",
          capabilities: ["order_query", "product_query", "category_query"]
        },
        health_check_url: nil
      }
    end
  end

  defp get_client_service_config do
    if Code.ensure_loaded?(ClientService) do
      %{
        name: "client-service",
        host: System.get_env("CLIENT_SERVICE_HOST", "localhost"),
        port: String.to_integer(System.get_env("CLIENT_SERVICE_PORT", "4000")),
        metadata: %{
          version: "1.0.0",
          capabilities: ["graphql", "websocket"]
        },
        health_check_url: nil
      }
    end
  end

  defp register_service(config) do
    case ServiceRegistry.register(
           config.name,
           config.host,
           config.port,
           metadata: config.metadata,
           health_check_url: config.health_check_url
         ) do
      {:ok, instance_id} ->
        Logger.info("Successfully registered #{config.name} at #{config.host}:#{config.port}")
        {config.name, instance_id}

      {:error, reason} ->
        Logger.error("Failed to register #{config.name}: #{inspect(reason)}")
        nil
    end
  end
end
