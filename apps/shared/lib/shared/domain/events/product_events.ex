defmodule Shared.Domain.Events.ProductEvents do
  @moduledoc """
  商品ドメインのイベント定義
  """

  defmodule ProductCreated do
    @moduledoc """
    商品作成イベント
    """
    use Shared.Domain.Events.BaseEvent

    @type t :: %__MODULE__{
            event_id: String.t(),
            aggregate_id: String.t(),
            name: String.t(),
            description: String.t() | nil,
            price: Decimal.t(),
            category_id: String.t(),
            occurred_at: DateTime.t(),
            metadata: map()
          }

    defstruct [
      :event_id,
      :aggregate_id,
      :name,
      :description,
      :price,
      :category_id,
      :occurred_at,
      :metadata
    ]

    @spec new(String.t(), String.t(), Decimal.t(), String.t(), map()) :: t()
    def new(product_id, name, price, category_id, metadata \\ %{}) do
      %__MODULE__{
        event_id: generate_event_id(),
        aggregate_id: product_id,
        name: name,
        description: metadata[:description],
        price: price,
        category_id: category_id,
        occurred_at: current_timestamp(),
        metadata: metadata
      }
    end

    @impl true
    def payload, do: %{}

    defp payload_to_map(event) do
      %{
        name: event.name,
        description: event.description,
        price: Decimal.to_string(event.price),
        category_id: event.category_id
      }
    end

    defp map_to_payload(map) do
      {:ok,
       %{
         name: map["name"] || map[:name],
         price: parse_price(map["price"] || map[:price]),
         category_id: map["category_id"] || map[:category_id]
       }}
    end

    defp parse_price(price) when is_binary(price), do: Decimal.new(price)
    defp parse_price(%Decimal{} = price), do: price
    defp parse_price(price) when is_number(price), do: Decimal.from_float(price * 1.0)
  end

  defmodule ProductUpdated do
    @moduledoc """
    商品更新イベント
    """
    use Shared.Domain.Events.BaseEvent

    @type t :: %__MODULE__{
            event_id: String.t(),
            aggregate_id: String.t(),
            changes: map(),
            occurred_at: DateTime.t(),
            metadata: map()
          }

    defstruct [:event_id, :aggregate_id, :changes, :occurred_at, :metadata]

    @spec new(String.t(), map(), map()) :: t()
    def new(product_id, changes, metadata \\ %{}) do
      %__MODULE__{
        event_id: generate_event_id(),
        aggregate_id: product_id,
        changes: changes,
        occurred_at: current_timestamp(),
        metadata: metadata
      }
    end

    @impl true
    def payload, do: %{}

    defp payload_to_map(event) do
      %{
        changes: serialize_changes(event.changes)
      }
    end

    defp map_to_payload(map) do
      {:ok,
       %{
         changes: deserialize_changes(map["changes"] || map[:changes])
       }}
    end

    defp serialize_changes(changes) do
      Enum.into(changes, %{}, fn
        {:price, %Decimal{} = price} -> {:price, Decimal.to_string(price)}
        {k, v} -> {k, v}
      end)
    end

    defp deserialize_changes(changes) do
      Enum.into(changes, %{}, fn
        {"price", price} -> {:price, Decimal.new(price)}
        {:price, price} when is_binary(price) -> {:price, Decimal.new(price)}
        {k, v} -> {String.to_atom(to_string(k)), v}
      end)
    end
  end

  defmodule ProductDeleted do
    @moduledoc """
    商品削除イベント
    """
    use Shared.Domain.Events.BaseEvent

    @type t :: %__MODULE__{
            event_id: String.t(),
            aggregate_id: String.t(),
            reason: String.t() | nil,
            occurred_at: DateTime.t(),
            metadata: map()
          }

    defstruct [:event_id, :aggregate_id, :reason, :occurred_at, :metadata]

    @spec new(String.t(), String.t() | nil, map()) :: t()
    def new(product_id, reason \\ nil, metadata \\ %{}) do
      %__MODULE__{
        event_id: generate_event_id(),
        aggregate_id: product_id,
        reason: reason,
        occurred_at: current_timestamp(),
        metadata: metadata
      }
    end

    @impl true
    def payload, do: %{}

    defp payload_to_map(event) do
      %{reason: event.reason}
    end

    defp map_to_payload(map) do
      {:ok,
       %{
         reason: map["reason"] || map[:reason]
       }}
    end
  end

  defmodule ProductPriceChanged do
    @moduledoc """
    商品価格変更イベント（特定のビジネスイベント）
    """
    use Shared.Domain.Events.BaseEvent

    @type t :: %__MODULE__{
            event_id: String.t(),
            aggregate_id: String.t(),
            old_price: Decimal.t(),
            new_price: Decimal.t(),
            change_reason: String.t() | nil,
            occurred_at: DateTime.t(),
            metadata: map()
          }

    defstruct [
      :event_id,
      :aggregate_id,
      :old_price,
      :new_price,
      :change_reason,
      :occurred_at,
      :metadata
    ]

    @spec new(String.t(), Decimal.t(), Decimal.t(), String.t() | nil, map()) :: t()
    def new(product_id, old_price, new_price, change_reason \\ nil, metadata \\ %{}) do
      %__MODULE__{
        event_id: generate_event_id(),
        aggregate_id: product_id,
        old_price: old_price,
        new_price: new_price,
        change_reason: change_reason,
        occurred_at: current_timestamp(),
        metadata: metadata
      }
    end

    @impl true
    def payload, do: %{}

    defp payload_to_map(event) do
      %{
        old_price: Decimal.to_string(event.old_price),
        new_price: Decimal.to_string(event.new_price),
        change_reason: event.change_reason
      }
    end

    defp map_to_payload(map) do
      {:ok,
       %{
         old_price: parse_price(map["old_price"] || map[:old_price]),
         new_price: parse_price(map["new_price"] || map[:new_price]),
         change_reason: map["change_reason"] || map[:change_reason]
       }}
    end

    defp parse_price(price) when is_binary(price), do: Decimal.new(price)
    defp parse_price(%Decimal{} = price), do: price
    defp parse_price(price) when is_number(price), do: Decimal.from_float(price * 1.0)
  end
end
