defmodule QueryService.Domain.Models.Category do
  @moduledoc """
  カテゴリ読み取り専用モデル

  クエリサービス用のカテゴリデータ構造を提供します
  """

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :created_at, :updated_at, :product_count]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          product_count: integer() | nil
        }

  @spec new(String.t(), String.t()) :: t()
  def new(id, name) do
    %__MODULE__{
      id: id,
      name: name
    }
  end

  @spec with_product_count(t(), integer()) :: t()
  def with_product_count(%__MODULE__{} = category, count) do
    %__MODULE__{category | product_count: count}
  end

  @spec with_timestamps(t(), DateTime.t(), DateTime.t()) :: t()
  def with_timestamps(%__MODULE__{} = category, created_at, updated_at) do
    %__MODULE__{category | created_at: created_at, updated_at: updated_at}
  end
end
