defmodule ElixirCqrs.EventStoreHelpers do
  @moduledoc """
  Test helpers for event sourcing and event store testing.
  """

  alias Shared.Infrastructure.EventStore
  alias ElixirCqrs.Factory

  @doc """
  Creates and stores an event in the event store.
  """
  def store_event(event_type, aggregate_id, event_data, opts \\ []) do
    version = Keyword.get(opts, :version, 1)
    expected_version = if version == 1, do: 0, else: version - 1
    
    event = %{
      event_id: Keyword.get(opts, :event_id, Ecto.UUID.generate()),
      event_type: event_type,
      aggregate_id: aggregate_id,
      aggregate_type: Keyword.get(opts, :aggregate_type, "test_aggregate"),
      event_data: event_data,
      event_metadata: Keyword.get(opts, :metadata, %{}),
      event_version: version,
      created_at: Keyword.get(opts, :created_at, DateTime.utc_now())
    }

    {:ok, _} = EventStore.save_aggregate_events(aggregate_id, [event], expected_version)
    event
  end

  @doc """
  Stores multiple events for an aggregate.
  """
  def store_events(aggregate_id, events) do
    events
    |> Enum.with_index(1)
    |> Enum.map(fn {{type, data}, version} ->
      store_event(type, aggregate_id, data, version: version)
    end)
  end

  @doc """
  Retrieves all events for an aggregate.
  """
  def get_aggregate_events(aggregate_id) do
    EventStore.get_events(aggregate_id)
  end

  @doc """
  Retrieves events by type.
  """
  def get_events_by_type(event_type) do
    EventStore.get_all_events()
    |> Enum.filter(&(&1.event_type == event_type))
  end

  @doc """
  Clears all events from the event store (for test cleanup).
  """
  def clear_event_store do
    # This should be implemented based on your event store schema
    # For testing, you might want to truncate the events table
    :ok
  end

  @doc """
  Creates a snapshot for testing.
  """
  def create_snapshot(aggregate_id, state, version) do
    %{
      aggregate_id: aggregate_id,
      aggregate_type: "test_aggregate",
      data: state,
      version: version,
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Asserts that events match expected patterns.
  """
  def assert_events_match(actual_events, expected_patterns) do
    assert length(actual_events) == length(expected_patterns)

    Enum.zip(actual_events, expected_patterns)
    |> Enum.each(fn {actual, expected} ->
      assert_event_matches(actual, expected)
    end)
  end

  defp assert_event_matches(actual_event, expected_pattern) do
    Enum.each(expected_pattern, fn {key, value} ->
      assert Map.get(actual_event, key) == value,
             "Expected #{key} to be #{inspect(value)}, got #{inspect(Map.get(actual_event, key))}"
    end)
  end

  @doc """
  Builds an event sequence for aggregate testing.
  """
  def build_event_sequence(aggregate_id, events) do
    events
    |> Enum.with_index(1)
    |> Enum.map(fn {{type, data}, version} ->
      # Factory.build を使わずに直接イベントを構築
      %{
        event_type: to_string(type),
        aggregate_id: aggregate_id,
        aggregate_type: "test_aggregate",
        event_data: data,
        event_metadata: %{},
        event_version: version,
        occurred_at: DateTime.utc_now()
      }
    end)
  end

  @doc """
  Replays events to rebuild aggregate state.
  """
  def replay_events(events, initial_state \\ %{}, apply_fn) do
    Enum.reduce(events, initial_state, fn event, state ->
      apply_fn.(state, event)
    end)
  end

  @doc """
  Creates a test saga context.
  """
  def create_saga_context(saga_id, aggregate_id, initial_data \\ %{}) do
    %{
      saga_id: saga_id,
      aggregate_id: aggregate_id,
      status: "started",
      current_step: 0,
      context: initial_data,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Simulates saga progression through events.
  """
  def progress_saga(saga, event) do
    # This would typically call the saga handler
    # and return the updated saga state and any commands
    {:ok, saga, []}
  end
end
