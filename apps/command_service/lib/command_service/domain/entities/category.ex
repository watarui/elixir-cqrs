defmodule CommandService.Domain.Entities.Category do
  @moduledoc """
  カテゴリエンティティ

  カテゴリのビジネスルールとドメインロジックを含みます
  """

  alias CommandService.Domain.ValueObjects.{CategoryId, CategoryName}

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :created_at, :updated_at]

  @type t :: %__MODULE__{
          id: CategoryId.t(),
          name: CategoryName.t(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec new(String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(id, name) do
    with {:ok, category_id} <- CategoryId.new(id),
         {:ok, category_name} <- CategoryName.new(name) do
      {:ok,
       %__MODULE__{
         id: category_id,
         name: category_name,
         created_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
       }}
    end
  end

  @spec update_name(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def update_name(%__MODULE__{} = category, new_name) do
    case CategoryName.new(new_name) do
      {:ok, name} ->
        {:ok, %__MODULE__{category | name: name, updated_at: DateTime.utc_now()}}

      error ->
        error
    end
  end

  @spec id(t()) :: String.t()
  def id(%__MODULE__{id: id}), do: CategoryId.value(id)

  @spec name(t()) :: String.t()
  def name(%__MODULE__{name: name}), do: CategoryName.value(name)

  @spec equals?(t(), t()) :: boolean()
  def equals?(%__MODULE__{id: id1}, %__MODULE__{id: id2}) do
    CategoryId.value(id1) == CategoryId.value(id2)
  end
end
