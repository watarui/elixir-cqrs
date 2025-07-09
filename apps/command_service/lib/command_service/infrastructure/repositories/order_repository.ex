defmodule CommandService.Infrastructure.Repositories.OrderRepository do
  @moduledoc """
  注文リポジトリの実装
  """

  @behaviour Shared.Domain.Repository

  alias CommandService.Domain.Aggregates.OrderAggregate
  alias Shared.Infrastructure.EventStore.EventStore
  alias Shared.Domain.ValueObjects.EntityId

  @aggregate_type "Order"

  @impl true
  def find_by_id(id) do
    case EntityId.from_string(id) do
      {:ok, entity_id} ->
        stream_name = "#{@aggregate_type}-#{entity_id.value}"
        
        case EventStore.get_events(stream_name) do
          {:ok, events} when events != [] ->
            aggregate = rebuild_aggregate_from_events(events)
            {:ok, aggregate}
          {:ok, []} ->
            {:error, :not_found}
          {:error, reason} ->
            {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def save(aggregate) do
    stream_name = "#{@aggregate_type}-#{aggregate.id.value}"
    
    case EventStore.append_events(stream_name, aggregate.uncommitted_events, aggregate.version) do
      {:ok, _} ->
        # uncommitted_events をクリア
        updated_aggregate = %{aggregate | 
          uncommitted_events: [],
          version: aggregate.version + length(aggregate.uncommitted_events)
        }
        {:ok, updated_aggregate}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete(id) do
    # イベントソーシングでは論理削除を使用
    {:error, "Delete not supported for event-sourced aggregates"}
  end

  # Private functions

  defp rebuild_aggregate_from_events(events) do
    Enum.reduce(events, OrderAggregate.new(), fn event, aggregate ->
      OrderAggregate.apply_event(aggregate, event)
    end)
  end
end