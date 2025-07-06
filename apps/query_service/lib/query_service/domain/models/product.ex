defmodule QueryService.Domain.Models.Product do
  @moduledoc """
  商品読み取り専用モデル

  クエリサービス用の商品データ構造を提供します
  """

  @enforce_keys [:id, :name, :price, :category_id]
  defstruct [:id, :name, :price, :category_id, :category_name, :created_at, :updated_at]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          price: Decimal.t(),
          category_id: String.t(),
          category_name: String.t() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec new(String.t(), String.t(), Decimal.t(), String.t()) :: t()
  def new(id, name, price, category_id) do
    %__MODULE__{
      id: id,
      name: name,
      price: price,
      category_id: category_id
    }
  end

  @spec with_category_name(t(), String.t()) :: t()
  def with_category_name(%__MODULE__{} = product, category_name) do
    %__MODULE__{product | category_name: category_name}
  end

  @spec with_timestamps(t(), DateTime.t(), DateTime.t()) :: t()
  def with_timestamps(%__MODULE__{} = product, created_at, updated_at) do
    %__MODULE__{product | created_at: created_at, updated_at: updated_at}
  end

  @spec price_string(t()) :: String.t()
  def price_string(%__MODULE__{price: price}) do
    Decimal.to_string(price)
  end

  @spec price_float(t()) :: float()
  def price_float(%__MODULE__{price: price}) do
    Decimal.to_float(price)
  end
end
