defmodule Shared.Domain.Events.CategoryEvents do
  @moduledoc """
  カテゴリドメインのイベント定義
  """

  defmodule CategoryCreated do
    @moduledoc """
    カテゴリ作成イベント
    """
    use Shared.Domain.Events.BaseEvent

    @type t :: %__MODULE__{
            event_id: String.t(),
            aggregate_id: String.t(),
            name: String.t(),
            occurred_at: DateTime.t(),
            metadata: map()
          }

    defstruct [:event_id, :aggregate_id, :name, :occurred_at, :metadata]

    @spec new(String.t(), String.t(), map()) :: t()
    def new(category_id, name, metadata \\ %{}) do
      %__MODULE__{
        event_id: generate_event_id(),
        aggregate_id: category_id,
        name: name,
        occurred_at: current_timestamp(),
        metadata: metadata
      }
    end

    @impl true
    def payload, do: %{}

    defp payload_to_map(event) do
      %{name: event.name}
    end

    defp map_to_payload(map) do
      {:ok, %{
        name: map["name"] || map[:name]
      }}
    end
  end

  defmodule CategoryUpdated do
    @moduledoc """
    カテゴリ更新イベント
    """
    use Shared.Domain.Events.BaseEvent

    @type t :: %__MODULE__{
            event_id: String.t(),
            aggregate_id: String.t(),
            old_name: String.t(),
            new_name: String.t(),
            occurred_at: DateTime.t(),
            metadata: map()
          }

    defstruct [:event_id, :aggregate_id, :old_name, :new_name, :occurred_at, :metadata]

    @spec new(String.t(), String.t(), String.t(), map()) :: t()
    def new(category_id, old_name, new_name, metadata \\ %{}) do
      %__MODULE__{
        event_id: generate_event_id(),
        aggregate_id: category_id,
        old_name: old_name,
        new_name: new_name,
        occurred_at: current_timestamp(),
        metadata: metadata
      }
    end

    @impl true
    def payload, do: %{}

    defp payload_to_map(event) do
      %{
        old_name: event.old_name,
        new_name: event.new_name
      }
    end

    defp map_to_payload(map) do
      {:ok, %{
        old_name: map["old_name"] || map[:old_name],
        new_name: map["new_name"] || map[:new_name]
      }}
    end
  end

  defmodule CategoryDeleted do
    @moduledoc """
    カテゴリ削除イベント
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
    def new(category_id, reason \\ nil, metadata \\ %{}) do
      %__MODULE__{
        event_id: generate_event_id(),
        aggregate_id: category_id,
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
      {:ok, %{
        reason: map["reason"] || map[:reason]
      }}
    end
  end

  defmodule CategoryProductsReassigned do
    @moduledoc """
    カテゴリ削除時の商品再割り当てイベント
    """
    use Shared.Domain.Events.BaseEvent

    @type t :: %__MODULE__{
            event_id: String.t(),
            aggregate_id: String.t(),
            from_category_id: String.t(),
            to_category_id: String.t(),
            product_ids: list(String.t()),
            occurred_at: DateTime.t(),
            metadata: map()
          }

    defstruct [:event_id, :aggregate_id, :from_category_id, :to_category_id, :product_ids, :occurred_at, :metadata]

    @spec new(String.t(), String.t(), list(String.t()), map()) :: t()
    def new(from_category_id, to_category_id, product_ids, metadata \\ %{}) do
      %__MODULE__{
        event_id: generate_event_id(),
        aggregate_id: from_category_id,
        from_category_id: from_category_id,
        to_category_id: to_category_id,
        product_ids: product_ids,
        occurred_at: current_timestamp(),
        metadata: metadata
      }
    end

    @impl true
    def payload, do: %{}

    defp payload_to_map(event) do
      %{
        from_category_id: event.from_category_id,
        to_category_id: event.to_category_id,
        product_ids: event.product_ids
      }
    end

    defp map_to_payload(map) do
      {:ok, %{
        from_category_id: map["from_category_id"] || map[:from_category_id],
        to_category_id: map["to_category_id"] || map[:to_category_id],
        product_ids: map["product_ids"] || map[:product_ids] || []
      }}
    end
  end
end