defmodule CommandService.Domain.Aggregates.CategoryAggregate do
  @moduledoc """
  カテゴリアグリゲート（イベントソーシング対応）
  
  カテゴリに関するすべてのビジネスロジックとイベント処理を管理します
  """

  alias CommandService.Domain.ValueObjects.{CategoryId, CategoryName}
  alias Shared.Domain.Events.CategoryEvents.{
    CategoryCreated,
    CategoryUpdated,
    CategoryDeleted
  }

  defstruct [:id, :name, :deleted, :version, :pending_events]

  @type t :: %__MODULE__{
          id: CategoryId.t() | nil,
          name: CategoryName.t() | nil,
          deleted: boolean(),
          version: non_neg_integer(),
          pending_events: list(struct())
        }

  use Shared.Domain.Aggregate.Base

  # コマンドハンドラー

  @impl true
  def execute(%__MODULE__{id: nil}, {:create_category, params}) do
    with {:ok, category_id} <- CategoryId.new(params.id),
         {:ok, category_name} <- CategoryName.new(params.name) do
      
      event = CategoryCreated.new(
        CategoryId.value(category_id),
        CategoryName.value(category_name),
        %{user_id: params[:user_id]}
      )
      
      {:ok, [event]}
    end
  end

  def execute(%__MODULE__{deleted: true}, _command) do
    {:error, "Cannot execute commands on deleted category"}
  end

  def execute(%__MODULE__{id: id} = aggregate, {:update_category, params}) when not is_nil(id) do
    case params[:name] do
      nil -> {:ok, []}
      "" -> {:ok, []}
      new_name ->
        case CategoryName.new(new_name) do
          {:ok, name} when name != aggregate.name ->
            event = CategoryUpdated.new(
              CategoryId.value(id),
              CategoryName.value(aggregate.name),
              CategoryName.value(name),
              %{user_id: params[:user_id]}
            )
            {:ok, [event]}
          _ ->
            {:ok, []}
        end
    end
  end

  def execute(%__MODULE__{id: id}, {:delete_category, params}) when not is_nil(id) do
    event = CategoryDeleted.new(
      CategoryId.value(id),
      params[:reason],
      %{user_id: params[:user_id]}
    )
    
    {:ok, [event]}
  end

  def execute(_aggregate, _command) do
    {:error, "Invalid command"}
  end

  # イベントハンドラー

  @impl true
  def apply_event(%__MODULE__{} = aggregate, %CategoryCreated{} = event) do
    with {:ok, category_id} <- CategoryId.new(event.aggregate_id),
         {:ok, category_name} <- CategoryName.new(event.name) do
      %__MODULE__{
        aggregate |
        id: category_id,
        name: category_name,
        deleted: false
      }
    else
      _ -> aggregate
    end
  end

  def apply_event(%__MODULE__{} = aggregate, %CategoryUpdated{} = event) do
    case CategoryName.new(event.new_name) do
      {:ok, name} -> %{aggregate | name: name}
      _ -> aggregate
    end
  end

  def apply_event(%__MODULE__{} = aggregate, %CategoryDeleted{}) do
    %{aggregate | deleted: true}
  end

  def apply_event(aggregate, _event), do: aggregate

  # アクセサ

  @spec id(t()) :: String.t() | nil
  def id(%__MODULE__{id: nil}), do: nil
  def id(%__MODULE__{id: id}), do: CategoryId.value(id)

  @spec name(t()) :: String.t() | nil
  def name(%__MODULE__{name: nil}), do: nil
  def name(%__MODULE__{name: name}), do: CategoryName.value(name)

  @spec deleted?(t()) :: boolean()
  def deleted?(%__MODULE__{deleted: deleted}), do: deleted || false

  # ファクトリー関数

  @spec new() :: t()
  def new do
    %__MODULE__{
      id: nil,
      name: nil,
      deleted: false,
      version: 0,
      pending_events: []
    }
  end

  @spec new(String.t()) :: t()
  def new(id) when is_binary(id) do
    case CategoryId.new(id) do
      {:ok, category_id} -> %__MODULE__{new() | id: category_id}
      _ -> new()
    end
  end
  
  @spec load_from_events(list(struct())) :: t()
  def load_from_events(events) do
    Enum.reduce(events, new(), fn event, aggregate ->
      aggregate
      |> apply_event(event)
      |> Map.update!(:version, &(&1 + 1))
    end)
  end
end