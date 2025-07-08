defmodule Shared.Domain.Events.CategoryEvents do
  @moduledoc """
  カテゴリに関連するドメインイベント
  """

  alias Shared.Domain.ValueObjects.{EntityId, CategoryName}

  defmodule CategoryCreated do
    @moduledoc """
    カテゴリ作成イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :name, :created_at]
    defstruct [:id, :name, :created_at]

    @type t :: %__MODULE__{
      id: EntityId.t(),
      name: CategoryName.t(),
      created_at: DateTime.t()
    }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        name: params.name,
        created_at: params[:created_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "category.created"

    @impl true
    def aggregate_type, do: "category"
  end

  defmodule CategoryUpdated do
    @moduledoc """
    カテゴリ更新イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :name, :updated_at]
    defstruct [:id, :name, :updated_at]

    @type t :: %__MODULE__{
      id: EntityId.t(),
      name: CategoryName.t(),
      updated_at: DateTime.t()
    }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        name: params.name,
        updated_at: params[:updated_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "category.updated"

    @impl true
    def aggregate_type, do: "category"
  end

  defmodule CategoryDeleted do
    @moduledoc """
    カテゴリ削除イベント
    """
    use Shared.Domain.Events.BaseEvent

    @enforce_keys [:id, :deleted_at]
    defstruct [:id, :deleted_at]

    @type t :: %__MODULE__{
      id: EntityId.t(),
      deleted_at: DateTime.t()
    }

    @impl true
    def new(params) do
      %__MODULE__{
        id: params.id,
        deleted_at: params[:deleted_at] || DateTime.utc_now()
      }
    end

    @impl true
    def event_type, do: "category.deleted"

    @impl true
    def aggregate_type, do: "category"
  end
end