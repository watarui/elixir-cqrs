defmodule Shared.EventStore do
  @moduledoc """
  完全なイベントソーシング実装（将来版）
  現在は使用せず、実装例として保持
  """

  @doc """
  イベントの永続化

  ## 例
      iex> EventStore.append_events("product-1", [%ProductCreated{...}])
      {:ok, 1}
  """
  def append_events(stream_id, events) do
    # 実装例：PostgreSQL への永続化
    # 現在は実装しない
    {:ok, length(events)}
  end

  @doc """
  イベントストリームの読み取り
  """
  def read_events(stream_id, from_version \\ 0) do
    # 実装例：PostgreSQL からの読み取り
    # 現在は実装しない
    {:ok, []}
  end

  @doc """
  イベントからの状態復元
  """
  def rebuild_aggregate(stream_id, aggregate_module) do
    with {:ok, events} <- read_events(stream_id) do
      aggregate_module.apply_events(events)
    end
  end
end

# 完全なイベントソーシング実装例（将来版）
defmodule Shared.EventSourcedAggregate do
  @moduledoc """
  イベントソーシング対応アグリゲート（将来版）
  """

  defmacro __using__(opts) do
    quote do
      @behaviour Shared.EventSourcedAggregate

      def load_from_history(stream_id) do
        with {:ok, events} <- Shared.EventStore.read_events(stream_id) do
          apply_events(events)
        end
      end

      def save_events(stream_id, events) do
        Shared.EventStore.append_events(stream_id, events)
      end
    end
  end

  @callback apply_events(list()) :: {:ok, term()} | {:error, term()}
end

# 使用例（将来版）
defmodule CommandService.Domain.Aggregates.ProductAggregate do
  @moduledoc """
  イベントソーシング対応商品アグリゲート（将来版）
  現在は使用しない
  """

  use Shared.EventSourcedAggregate

  defstruct [:id, :name, :price, :category_id, :version]

  def apply_events(events) do
    events
    |> Enum.reduce(%__MODULE__{}, &apply_event(&2, &1))
    |> then(&{:ok, &1})
  end

  # イベント適用（将来版）
  defp apply_event(aggregate, %Shared.Events.ProductCreated{} = event) do
    %{
      aggregate
      | id: event.id,
        name: event.name,
        price: event.price,
        category_id: event.category_id,
        version: aggregate.version + 1
    }
  end

  defp apply_event(aggregate, %Shared.Events.ProductUpdated{} = event) do
    %{
      aggregate
      | name: event.new_data.name,
        price: event.new_data.price,
        version: aggregate.version + 1
    }
  end

  defp apply_event(aggregate, _event), do: aggregate
end
