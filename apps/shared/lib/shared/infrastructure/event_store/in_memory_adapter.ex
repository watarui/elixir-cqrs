defmodule Shared.Infrastructure.EventStore.InMemoryAdapter do
  @moduledoc """
  開発・テスト用のインメモリイベントストア実装
  """

  use GenServer
  @behaviour Shared.Infrastructure.EventStore.EventStoreBehaviour

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def append_to_stream(stream_name, events, expected_version) do
    GenServer.call(get_server(), {:append_to_stream, stream_name, events, expected_version})
  end

  @impl true
  def read_stream_forward(stream_name, from_version, count) do
    GenServer.call(get_server(), {:read_stream_forward, stream_name, from_version, count})
  end

  @impl true
  def read_all_events(from_position) do
    GenServer.call(get_server(), {:read_all_events, from_position})
  end

  @impl true
  def read_events_by_type(event_type, from_position) do
    GenServer.call(get_server(), {:read_events_by_type, event_type, from_position})
  end

  @impl true
  def create_snapshot(aggregate_id, snapshot, version) do
    GenServer.call(get_server(), {:create_snapshot, aggregate_id, snapshot, version})
  end

  @impl true
  def get_snapshot(aggregate_id) do
    GenServer.call(get_server(), {:get_snapshot, aggregate_id})
  end

  # Server callbacks

  @impl GenServer
  def init(:ok) do
    state = %{
      streams: %{},
      global_events: [],
      snapshots: %{},
      global_position: 0
    }
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:append_to_stream, stream_name, events, expected_version}, _from, state) do
    stream = Map.get(state.streams, stream_name, %{events: [], version: 0})
    
    if stream.version != expected_version do
      {:reply, {:error, :wrong_expected_version}, state}
    else
      new_events = Enum.map(events, fn event ->
        %{
          event: event,
          stream_name: stream_name,
          stream_version: stream.version + 1,
          global_position: state.global_position + 1,
          timestamp: DateTime.utc_now()
        }
      end)
      
      new_stream = %{
        events: stream.events ++ new_events,
        version: stream.version + length(events)
      }
      
      new_state = %{
        state |
        streams: Map.put(state.streams, stream_name, new_stream),
        global_events: state.global_events ++ new_events,
        global_position: state.global_position + length(events)
      }
      
      {:reply, {:ok, new_stream.version}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:read_stream_forward, stream_name, from_version, count}, _from, state) do
    stream = Map.get(state.streams, stream_name, %{events: [], version: 0})
    
    events = stream.events
    |> Enum.filter(fn e -> e.stream_version > from_version end)
    |> maybe_take(count)
    |> Enum.map(& &1.event)
    
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:read_all_events, from_position}, _from, state) do
    events = state.global_events
    |> Enum.filter(fn e -> e.global_position > from_position end)
    |> Enum.map(& &1.event)
    
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:read_events_by_type, event_type, from_position}, _from, state) do
    events = state.global_events
    |> Enum.filter(fn e -> 
      e.global_position > from_position && 
      event_type_matches?(e.event, event_type)
    end)
    |> Enum.map(& &1.event)
    
    {:reply, {:ok, events}, state}
  end

  @impl GenServer
  def handle_call({:create_snapshot, aggregate_id, snapshot, version}, _from, state) do
    new_snapshots = Map.put(state.snapshots, aggregate_id, {snapshot, version})
    {:reply, :ok, %{state | snapshots: new_snapshots}}
  end

  @impl GenServer
  def handle_call({:get_snapshot, aggregate_id}, _from, state) do
    case Map.get(state.snapshots, aggregate_id) do
      nil -> {:reply, {:error, :not_found}, state}
      snapshot -> {:reply, {:ok, snapshot}, state}
    end
  end

  # プライベート関数

  defp get_server do
    case Process.whereis(__MODULE__) do
      nil -> 
        {:ok, pid} = start_link(name: __MODULE__)
        pid
      pid -> 
        pid
    end
  end

  defp maybe_take(events, :all), do: events
  defp maybe_take(events, count), do: Enum.take(events, count)

  defp event_type_matches?(event, event_type) do
    event.__struct__ 
    |> Module.split() 
    |> List.last() 
    |> String.to_atom() == event_type
  end
end