defmodule ClientService.Infrastructure.GrpcConnections do
  @moduledoc """
  gRPC接続管理 - Command Service と Query Service への接続
  """

  use GenServer
  require Logger

  # クライアント状態
  defstruct [:command_channel, :query_channel, :connections]

  @type t :: %__MODULE__{
          command_channel: GRPC.Channel.t() | nil,
          query_channel: GRPC.Channel.t() | nil,
          connections: map()
        }

  @command_service_host Application.compile_env(
                          :client_service,
                          :command_service_host,
                          "localhost"
                        )
  @command_service_port Application.compile_env(:client_service, :command_service_port, 50051)
  @query_service_host Application.compile_env(:client_service, :query_service_host, "localhost")
  @query_service_port Application.compile_env(:client_service, :query_service_port, 50052)

  # 接続タイムアウト
  @connect_timeout 5000

  # 再接続間隔
  @reconnect_interval 3000

  ## Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Command Service への接続を取得
  """
  @spec get_command_channel() :: {:ok, GRPC.Channel.t()} | {:error, String.t()}
  def get_command_channel do
    GenServer.call(__MODULE__, :get_command_channel)
  end

  @doc """
  Query Service への接続を取得
  """
  @spec get_query_channel() :: {:ok, GRPC.Channel.t()} | {:error, String.t()}
  def get_query_channel do
    GenServer.call(__MODULE__, :get_query_channel)
  end

  @doc """
  接続状態を取得
  """
  @spec get_connection_status() :: %{command: atom(), query: atom()}
  def get_connection_status do
    GenServer.call(__MODULE__, :get_connection_status)
  end

  @doc """
  接続を手動で再設定
  """
  @spec reconnect() :: :ok
  def reconnect do
    GenServer.cast(__MODULE__, :reconnect)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting gRPC connection manager")

    # 初期接続を非同期で実行
    send(self(), :init_connections)

    {:ok, %__MODULE__{connections: %{}}}
  end

  @impl true
  def handle_call(:get_command_channel, _from, state) do
    case state.command_channel do
      nil ->
        {:reply, {:error, "Command service not connected"}, state}

      channel ->
        {:reply, {:ok, channel}, state}
    end
  end

  @impl true
  def handle_call(:get_query_channel, _from, state) do
    case state.query_channel do
      nil ->
        {:reply, {:error, "Query service not connected"}, state}

      channel ->
        {:reply, {:ok, channel}, state}
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
    Logger.info("Reconnecting to gRPC services")

    # 既存の接続を閉じる
    close_connections(state)

    # 新しい接続を作成
    send(self(), :init_connections)

    {:noreply, %{state | command_channel: nil, query_channel: nil}}
  end

  @impl true
  def handle_info(:init_connections, state) do
    Logger.info("Initializing gRPC connections")

    # Command Service への接続
    command_result = connect_to_command_service()

    # Query Service への接続
    query_result = connect_to_query_service()

    new_state = %{
      state
      | command_channel: extract_channel(command_result),
        query_channel: extract_channel(query_result)
    }

    # 接続に失敗した場合は再試行をスケジュール
    if should_retry_connection?(command_result, query_result) do
      Process.send_after(self(), :retry_connections, @reconnect_interval)
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:retry_connections, state) do
    Logger.info("Retrying gRPC connections")

    # 失敗した接続のみ再試行
    new_state =
      state
      |> retry_command_connection()
      |> retry_query_connection()

    # まだ接続に失敗している場合は再び再試行をスケジュール
    if new_state.command_channel == nil or new_state.query_channel == nil do
      Process.send_after(self(), :retry_connections, @reconnect_interval)
    end

    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("Terminating gRPC connection manager")
    close_connections(state)
    :ok
  end

  ## プライベート関数

  defp extract_channel({:ok, channel}), do: channel
  defp extract_channel({:error, _reason}), do: nil

  defp should_retry_connection?(command_result, query_result) do
    match?({:error, _}, command_result) or match?({:error, _}, query_result)
  end

  defp connect_to_command_service do
    Logger.info(
      "Connecting to Command Service at #{@command_service_host}:#{@command_service_port}"
    )

    case GRPC.Stub.connect("#{@command_service_host}:#{@command_service_port}",
           adapter: GRPC.Client.Adapters.Gun,
           adapter_opts: [timeout: @connect_timeout]
         ) do
      {:ok, channel} ->
        Logger.info("Connected to Command Service")
        {:ok, channel}

      {:error, reason} ->
        Logger.error("Failed to connect to Command Service: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp connect_to_query_service do
    Logger.info("Connecting to Query Service at #{@query_service_host}:#{@query_service_port}")

    case GRPC.Stub.connect("#{@query_service_host}:#{@query_service_port}",
           adapter: GRPC.Client.Adapters.Gun,
           adapter_opts: [timeout: @connect_timeout]
         ) do
      {:ok, channel} ->
        Logger.info("Connected to Query Service")
        {:ok, channel}

      {:error, reason} ->
        Logger.error("Failed to connect to Query Service: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp retry_command_connection(state) do
    if state.command_channel == nil do
      case connect_to_command_service() do
        {:ok, channel} -> %{state | command_channel: channel}
        {:error, _} -> state
      end
    else
      state
    end
  end

  defp retry_query_connection(state) do
    if state.query_channel == nil do
      case connect_to_query_service() do
        {:ok, channel} -> %{state | query_channel: channel}
        {:error, _} -> state
      end
    else
      state
    end
  end

  defp close_connections(state) do
    if state.command_channel do
      GRPC.Stub.disconnect(state.command_channel)
    end

    if state.query_channel do
      GRPC.Stub.disconnect(state.query_channel)
    end
  end
end
