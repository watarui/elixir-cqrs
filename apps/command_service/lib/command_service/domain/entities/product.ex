defmodule CommandService.Domain.Entities.Product do
  @moduledoc """
  商品エンティティ

  商品のビジネスルールとドメインロジックを含みます
  """

  alias CommandService.Domain.ValueObjects.{ProductId, ProductName, ProductPrice, CategoryId}

  @enforce_keys [:id, :name, :price, :category_id]
  defstruct [:id, :name, :price, :category_id, :created_at, :updated_at]

  @type t :: %__MODULE__{
          id: ProductId.t(),
          name: ProductName.t(),
          price: ProductPrice.t(),
          category_id: CategoryId.t(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec new(String.t(), String.t(), String.t() | number(), String.t()) ::
          {:ok, t()} | {:error, String.t()}
  def new(id, name, price, category_id) do
    with {:ok, product_id} <- ProductId.new(id),
         {:ok, product_name} <- ProductName.new(name),
         {:ok, product_price} <- ProductPrice.new(price),
         {:ok, cat_id} <- CategoryId.new(category_id) do
      {:ok,
       %__MODULE__{
         id: product_id,
         name: product_name,
         price: product_price,
         category_id: cat_id,
         created_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
       }}
    end
  end

  @spec update_name(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def update_name(%__MODULE__{} = product, new_name) do
    case ProductName.new(new_name) do
      {:ok, name} ->
        {:ok, %__MODULE__{product | name: name, updated_at: DateTime.utc_now()}}

      error ->
        error
    end
  end

  @spec update_price(t(), String.t() | number()) :: {:ok, t()} | {:error, String.t()}
  def update_price(%__MODULE__{} = product, new_price) do
    case ProductPrice.new(new_price) do
      {:ok, price} ->
        {:ok, %__MODULE__{product | price: price, updated_at: DateTime.utc_now()}}

      error ->
        error
    end
  end

  @spec update_category(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def update_category(%__MODULE__{} = product, new_category_id) do
    case CategoryId.new(new_category_id) do
      {:ok, category_id} ->
        {:ok, %__MODULE__{product | category_id: category_id, updated_at: DateTime.utc_now()}}

      error ->
        error
    end
  end

  @spec id(t()) :: String.t()
  def id(%__MODULE__{id: id}), do: ProductId.value(id)

  @spec name(t()) :: String.t()
  def name(%__MODULE__{name: name}), do: ProductName.value(name)

  @spec price(t()) :: Decimal.t()
  def price(%__MODULE__{price: price}), do: ProductPrice.value(price)

  @spec category_id(t()) :: String.t()
  def category_id(%__MODULE__{category_id: category_id}), do: CategoryId.value(category_id)

  @spec equals?(t(), t()) :: boolean()
  def equals?(%__MODULE__{id: id1}, %__MODULE__{id: id2}) do
    ProductId.value(id1) == ProductId.value(id2)
  end
end
