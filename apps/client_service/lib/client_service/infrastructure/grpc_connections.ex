defmodule ClientService.Infrastructure.GrpcConnections do
  @moduledoc """
  gRPC サービスとの接続を管理する GenServer
  """

  use GenServer
  require Logger

  alias GRPC.Channel
  alias Shared.Infrastructure.Grpc.CircuitBreaker

  # 接続設定
  @default_host "localhost"
  @default_command_port 50051
  @default_query_port 50052

  # 接続再試行設定
  @reconnect_interval 5000
  @max_reconnect_attempts 10

  # 接続状態
  defmodule State do
    @moduledoc false
    defstruct command_channel: nil,
              query_channel: nil,
              command_host: "localhost",
              command_port: 50051,
              query_host: "localhost",
              query_port: 50052,
              reconnect_attempts: %{command: 0, query: 0}
  end

  # クライアントAPI

  @doc """
  gRPC接続管理プロセスを開始する
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  コマンドサービスのチャンネルを取得する
  """
  @spec get_command_channel() :: {:ok, GRPC.Channel.t()} | {:error, term()}
  def get_command_channel do
    case GenServer.call(__MODULE__, :get_command_channel) do
      {:ok, channel} -> {:ok, channel}
      error -> error
    end
  end

  @doc """
  クエリサービスのチャンネルを取得する
  """
  @spec get_query_channel() :: {:ok, GRPC.Channel.t()} | {:error, term()}
  def get_query_channel do
    case GenServer.call(__MODULE__, :get_query_channel) do
      {:ok, channel} -> {:ok, channel}
      error -> error
    end
  end

  @doc """
  全接続の状態を取得する
  """
  @spec get_connection_status() :: map()
  def get_connection_status do
    GenServer.call(__MODULE__, :get_connection_status)
  end

  @doc """
  接続を強制的に再接続する
  """
  @spec reconnect() :: :ok
  def reconnect do
    GenServer.cast(__MODULE__, :reconnect)
  end

  # GenServer コールバック

  @impl true
  def init([]) do
    # サーキットブレーカーを起動
    {:ok, _} = CircuitBreaker.start_link(
      name: :command_service_cb,
      options: %{
        failure_threshold: 5,
        success_threshold: 2,
        timeout: 30_000
      }
    )
    
    {:ok, _} = CircuitBreaker.start_link(
      name: :query_service_cb,
      options: %{
        failure_threshold: 5,
        success_threshold: 2,
        timeout: 30_000
      }
    )
    state = %State{
      command_host: get_env_or_default(:command_service_host, @default_host),
      command_port: get_env_or_default(:command_service_port, @default_command_port),
      query_host: get_env_or_default(:query_service_host, @default_host),
      query_port: get_env_or_default(:query_service_port, @default_query_port)
    }

    Logger.info("Starting gRPC connection manager")

    # 初期接続を試行
    send(self(), :connect_all)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_command_channel, _from, state) do
    case state.command_channel do
      %Channel{} = channel ->
        {:reply, {:ok, channel}, state}

      nil ->
        Logger.warning("Command service channel not available")
        {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:get_query_channel, _from, state) do
    case state.query_channel do
      %Channel{} = channel ->
        {:reply, {:ok, channel}, state}

      nil ->
        Logger.warning("Query service channel not available")
        {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:get_connection_status, _from, state) do
    status = %{
      command: if(state.command_channel, do: :connected, else: :disconnected),
      query: if(state.query_channel, do: :connected, else: :disconnected)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:reconnect, state) do
    Logger.info("Forcing reconnection to gRPC services")
    send(self(), :connect_all)
    {:noreply, state}
  end

  @impl true
  def handle_info(:connect_all, state) do
    Logger.info("Connecting to gRPC services...")

    new_state =
      state
      |> connect_command_service()
      |> connect_query_service()

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:reconnect, service_type}, state) do
    case service_type do
      :command ->
        new_state = connect_command_service(state)
        {:noreply, new_state}

      :query ->
        new_state = connect_query_service(state)
        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # プライベート関数

  defp connect_command_service(state) do
    endpoint = "#{state.command_host}:#{state.command_port}"

    case GRPC.Stub.connect(endpoint, interceptors: []) do
      {:ok, channel} ->
        Logger.info("Successfully connected to command service at #{endpoint}")

        %{
          state
          | command_channel: channel,
            reconnect_attempts: %{state.reconnect_attempts | command: 0}
        }

      {:error, reason} ->
        Logger.error("Failed to connect to command service at #{endpoint}: #{inspect(reason)}")
        schedule_reconnect(:command, state, :command)

        %{state | command_channel: nil}
    end
  end

  defp connect_query_service(state) do
    endpoint = "#{state.query_host}:#{state.query_port}"

    case GRPC.Stub.connect(endpoint, interceptors: []) do
      {:ok, channel} ->
        Logger.info("Successfully connected to query service at #{endpoint}")

        %{
          state
          | query_channel: channel,
            reconnect_attempts: %{state.reconnect_attempts | query: 0}
        }

      {:error, reason} ->
        Logger.error("Failed to connect to query service at #{endpoint}: #{inspect(reason)}")
        schedule_reconnect(:query, state, :query)

        %{state | query_channel: nil}
    end
  end

  defp schedule_reconnect(service_type, state, attempts_key) do
    current_attempts = Map.get(state.reconnect_attempts, attempts_key, 0)

    if current_attempts < @max_reconnect_attempts do
      Logger.info(
        "Scheduling reconnection for #{service_type} service in #{@reconnect_interval}ms (attempt #{current_attempts + 1})"
      )

      Process.send_after(self(), {:reconnect, service_type}, @reconnect_interval)

      new_attempts = Map.put(state.reconnect_attempts, attempts_key, current_attempts + 1)
      %{state | reconnect_attempts: new_attempts}
    else
      Logger.error("Max reconnection attempts reached for #{service_type} service")
      state
    end
  end

  defp get_env_or_default(key, default) do
    # 環境変数から読み取る
    env_key = key |> Atom.to_string() |> String.upcase()
    
    case System.get_env(env_key) do
      nil ->
        # 環境変数がない場合はアプリケーション設定を確認
        case Application.get_env(:client_service, key) do
          nil -> default
          value -> value
        end
      value -> 
        # ポート番号の場合は整数に変換
        if String.ends_with?(env_key, "_PORT") do
          String.to_integer(value)
        else
          value
        end
    end
  end
  
  @doc """
  サーキットブレーカーの状態を取得する
  """
  @spec get_circuit_breaker_status() :: map()
  def get_circuit_breaker_status do
    %{
      command: CircuitBreaker.get_state(:command_service_cb),
      query: CircuitBreaker.get_state(:query_service_cb)
    }
  end
  
  @doc """
  サーキットブレーカーをリセットする
  """
  @spec reset_circuit_breakers() :: :ok
  def reset_circuit_breakers do
    CircuitBreaker.reset(:command_service_cb)
    CircuitBreaker.reset(:query_service_cb)
    :ok
  end
end
