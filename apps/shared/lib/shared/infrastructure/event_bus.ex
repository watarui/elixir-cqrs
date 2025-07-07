defmodule Shared.Infrastructure.EventBus do
  @moduledoc """
  イベントバス
  
  イベントの発行と購読を管理します
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  イベントを発行する
  """
  @spec publish(event :: struct()) :: :ok
  def publish(event) do
    GenServer.cast(get_server(), {:publish, event})
  end

  @doc """
  イベントハンドラーを登録する
  """
  @spec subscribe(handler :: pid() | module()) :: :ok
  def subscribe(handler) do
    GenServer.call(get_server(), {:subscribe, handler})
  end

  @doc """
  特定のイベントタイプにハンドラーを登録する
  """
  @spec subscribe_to(event_type :: atom(), handler :: function()) :: :ok
  def subscribe_to(event_type, handler) do
    GenServer.call(get_server(), {:subscribe_to, event_type, handler})
  end

  # Server callbacks

  @impl GenServer
  def init(:ok) do
    state = %{
      subscribers: [],
      typed_subscribers: %{}
    }
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:subscribe, handler}, _from, state) do
    {:reply, :ok, %{state | subscribers: [handler | state.subscribers]}}
  end

  def handle_call({:subscribe_to, event_type, handler}, _from, state) do
    handlers = Map.get(state.typed_subscribers, event_type, [])
    new_typed_subscribers = Map.put(state.typed_subscribers, event_type, [handler | handlers])
    {:reply, :ok, %{state | typed_subscribers: new_typed_subscribers}}
  end

  @impl GenServer
  def handle_cast({:publish, event}, state) do
    event_type = event.__struct__
    
    # 全体購読者に通知
    Enum.each(state.subscribers, fn
      pid when is_pid(pid) ->
        send(pid, {:event, event})
      
      module when is_atom(module) ->
        Task.start(fn -> module.handle_event(event) end)
    end)
    
    # タイプ別購読者に通知
    case Map.get(state.typed_subscribers, event_type) do
      nil -> :ok
      handlers ->
        Enum.each(handlers, fn handler ->
          Task.start(fn -> handler.(event) end)
        end)
    end
    
    Logger.debug("Published event: #{inspect(event_type)}")
    
    {:noreply, state}
  end

  # Private functions

  defp get_server do
    case Process.whereis(__MODULE__) do
      nil -> 
        {:ok, pid} = start_link(name: __MODULE__)
        pid
      pid -> 
        pid
    end
  end
end