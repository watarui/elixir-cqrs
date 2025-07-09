defmodule ClientService.Infrastructure.GrpcConnections do
  @moduledoc """
  gRPC 接続の管理
  
  Command Service と Query Service への接続を管理します
  """

  use GenServer
  require Logger

  @command_service_port 50051
  @query_service_port 50052

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Command Service のチャンネルを取得する
  """
  def get_command_channel do
    GenServer.call(__MODULE__, :get_command_channel)
  end

  @doc """
  Query Service のチャンネルを取得する
  """
  def get_query_channel do
    GenServer.call(__MODULE__, :get_query_channel)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # 起動時に接続を確立
    state = %{
      command_channel: nil,
      query_channel: nil
    }
    
    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    new_state = 
      state
      |> connect_command_service()
      |> connect_query_service()
    
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_command_channel, _from, state) do
    case state.command_channel do
      nil ->
        # 再接続を試みる
        new_state = connect_command_service(state)
        {:reply, new_state.command_channel, new_state}
      channel ->
        {:reply, channel, state}
    end
  end

  @impl true
  def handle_call(:get_query_channel, _from, state) do
    case state.query_channel do
      nil ->
        # 再接続を試みる
        new_state = connect_query_service(state)
        {:reply, new_state.query_channel, new_state}
      channel ->
        {:reply, channel, state}
    end
  end

  # Private functions

  defp connect_command_service(state) do
    host = Application.get_env(:client_service, :command_service_host, "localhost")
    
    case GRPC.Stub.connect("#{host}:#{@command_service_port}") do
      {:ok, channel} ->
        Logger.info("Connected to Command Service at #{host}:#{@command_service_port}")
        %{state | command_channel: channel}
      {:error, reason} ->
        Logger.error("Failed to connect to Command Service: #{inspect(reason)}")
        state
    end
  end

  defp connect_query_service(state) do
    host = Application.get_env(:client_service, :query_service_host, "localhost")
    
    case GRPC.Stub.connect("#{host}:#{@query_service_port}") do
      {:ok, channel} ->
        Logger.info("Connected to Query Service at #{host}:#{@query_service_port}")
        %{state | query_channel: channel}
      {:error, reason} ->
        Logger.error("Failed to connect to Query Service: #{inspect(reason)}")
        state
    end
  end
end