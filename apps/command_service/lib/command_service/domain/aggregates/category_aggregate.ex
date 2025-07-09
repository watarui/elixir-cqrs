defmodule CommandService.Domain.Aggregates.CategoryAggregate do
  @moduledoc """
  カテゴリアグリゲート

  カテゴリの作成、更新、削除に関するビジネスロジックを管理します
  """

  use Shared.Domain.Aggregate.Base

  alias Shared.Domain.ValueObjects.{EntityId, CategoryName}
  alias Shared.Domain.Events.CategoryEvents.{CategoryCreated, CategoryUpdated, CategoryDeleted}

  @enforce_keys [:id]
  defstruct [:id, :name, :version, :deleted, :created_at, :updated_at, uncommitted_events: []]

  @type t :: %__MODULE__{
          id: EntityId.t(),
          name: CategoryName.t() | nil,
          version: integer(),
          deleted: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          uncommitted_events: list()
        }

  @impl true
  def new do
    %__MODULE__{
      id: EntityId.generate(),
      version: 0,
      deleted: false,
      uncommitted_events: []
    }
  end

  @doc """
  カテゴリを作成する
  """
  @spec create(String.t()) :: {:ok, t()} | {:error, String.t()}
  def create(name) do
    with {:ok, category_name} <- CategoryName.new(name) do
      aggregate = new()

      event =
        CategoryCreated.new(%{
          id: aggregate.id,
          name: category_name,
          created_at: DateTime.utc_now()
        })

      {:ok, apply_and_record_event(aggregate, event)}
    end
  end

  @doc """
  カテゴリ名を更新する
  """
  @spec update_name(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def update_name(%__MODULE__{deleted: true}, _name) do
    {:error, "Cannot update deleted category"}
  end

  def update_name(%__MODULE__{} = aggregate, name) do
    with {:ok, category_name} <- CategoryName.new(name) do
      if aggregate.name && aggregate.name.value == category_name.value do
        {:error, "Name is the same"}
      else
        event =
          CategoryUpdated.new(%{
            id: aggregate.id,
            name: category_name,
            updated_at: DateTime.utc_now()
          })

        {:ok, apply_and_record_event(aggregate, event)}
      end
    end
  end

  @doc """
  カテゴリを削除する
  """
  @spec delete(t()) :: {:ok, t()} | {:error, String.t()}
  def delete(%__MODULE__{deleted: true}) do
    {:error, "Category already deleted"}
  end

  def delete(%__MODULE__{} = aggregate) do
    event =
      CategoryDeleted.new(%{
        id: aggregate.id,
        deleted_at: DateTime.utc_now()
      })

    {:ok, apply_and_record_event(aggregate, event)}
  end

  @impl true
  def apply_event(aggregate, %CategoryCreated{} = event) do
    %{
      aggregate
      | id: event.id,
        name: event.name,
        created_at: event.created_at,
        updated_at: event.created_at
    }
  end

  def apply_event(aggregate, %CategoryUpdated{} = event) do
    %{aggregate | name: event.name, updated_at: event.updated_at}
  end

  def apply_event(aggregate, %CategoryDeleted{} = _event) do
    %{aggregate | deleted: true, updated_at: DateTime.utc_now()}
  end
end
