defmodule CommandService.Application.Services.ProductService do
  @moduledoc """
  商品アプリケーションサービス

  商品に関するビジネスロジックとオーケストレーションを提供します
  """

  alias CommandService.Domain.Entities.Product
  alias CommandService.Infrastructure.Repositories.ProductRepository, as: ProductRepo

  @repo ProductRepo

  @spec create_product(map()) :: {:ok, Product.t()} | {:error, String.t()}
  def create_product(params) do
    id = UUID.uuid4()

    with {:ok, product} <- Product.new(id, params[:name], params[:price], params[:category_id]),
         {:ok, saved_product} <- @repo.save(product) do
      {:ok, saved_product}
    end
  end

  @spec get_product(String.t()) :: {:ok, Product.t()} | {:error, :not_found | String.t()}
  def get_product(id) do
    @repo.find_by_id(id)
  end

  @doc """
  Updates a product with the given parameters.
  
  ## Parameters
    - `id`: The product ID
    - `params`: A map containing the fields to update
      - `:name` - The new product name (skipped if nil or empty string)
      - `:price` - The new product price (skipped if nil, empty string, or "0.0")
      - `:category_id` - The new category ID (skipped if nil or empty string)
  
  ## Returns
    - `{:ok, Product.t()}` - The updated product
    - `{:error, String.t()}` - An error message if the update fails
  
  ## Notes
    Only non-nil and non-empty values will be updated. Price cannot be set to zero.
  """
  @spec update_product(String.t(), map()) :: {:ok, Product.t()} | {:error, String.t()}
  def update_product(id, params) do
    with {:ok, product} <- @repo.find_by_id(id),
         {:ok, updated_product} <- apply_updates(product, params),
         {:ok, saved_product} <- @repo.update(updated_product) do
      {:ok, saved_product}
    end
  end

  defp apply_updates(product, params) do
    update_fields = [
      {:name, params[:name], &Product.update_name/2},
      {:price, params[:price], &Product.update_price/2},
      {:category_id, params[:category_id], &Product.update_category/2}
    ]

    Enum.reduce_while(update_fields, {:ok, product}, fn {field, value, update_fn}, {:ok, product} ->
      case maybe_apply_update(product, field, value, update_fn) do
        {:ok, updated_product} -> {:cont, {:ok, updated_product}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  # Skip update if value is nil or empty
  defp maybe_apply_update(product, _field, value, _update_fn) when is_nil(value), do: {:ok, product}
  defp maybe_apply_update(product, _field, "", _update_fn), do: {:ok, product}
  
  # Skip price update if value is zero (business rule: prevent setting price to zero)
  defp maybe_apply_update(product, :price, value, _update_fn) when value in ["0.0", 0.0], do: {:ok, product}
  
  # Apply the update
  defp maybe_apply_update(product, _field, value, update_fn), do: update_fn.(product, value)

  @spec delete_product(String.t()) :: :ok | {:error, String.t()}
  def delete_product(id) do
    @repo.delete(id)
  end

  @spec list_products() :: {:ok, [Product.t()]} | {:error, String.t()}
  def list_products do
    @repo.list()
  end

  @spec product_exists?(String.t()) :: boolean()
  def product_exists?(id) do
    @repo.exists?(id)
  end
end
