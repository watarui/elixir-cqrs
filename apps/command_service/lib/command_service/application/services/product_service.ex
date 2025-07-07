defmodule CommandService.Application.Services.ProductService do
  @moduledoc """
  商品アプリケーションサービス

  商品に関するビジネスロジックとオーケストレーションを提供します
  """

  alias CommandService.Domain.Entities.Product
  alias CommandService.Infrastructure.Repositories.ProductRepository, as: ProductRepo
  alias Shared.Errors.{AppError, ErrorConverter}

  # デフォルトのリポジトリ実装
  @default_repo ProductRepo

  @spec create_product(map(), module()) :: {:ok, Product.t()} | {:error, String.t() | AppError.t()}
  def create_product(params, repo \\ @default_repo) do
    id = UUID.uuid4()

    with {:ok, product} <- Product.new(id, params[:name], params[:price], params[:category_id]),
         {:ok, saved_product} <- repo.save(product) do
      {:ok, saved_product}
    end
  end

  @spec get_product(String.t(), module()) :: {:ok, Product.t()} | {:error, :not_found | String.t() | AppError.t()}
  def get_product(id, repo \\ @default_repo) do
    repo.find_by_id(id)
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
  @spec update_product(String.t(), map(), module()) :: {:ok, Product.t()} | {:error, String.t() | AppError.t()}
  def update_product(id, params, repo \\ @default_repo) do
    with {:ok, product} <- repo.find_by_id(id),
         # ビジネスルール: 価格を0に設定することを防ぐ
         filtered_params = filter_zero_price(params),
         {:ok, updated_product} <- Product.update(product, filtered_params),
         {:ok, saved_product} <- repo.update(updated_product) do
      {:ok, saved_product}
    end
  end

  # 価格が0の場合は除外する（ビジネスルール）
  defp filter_zero_price(params) do
    case params[:price] do
      "0.0" -> Map.delete(params, :price)
      price when is_float(price) and price == 0.0 -> Map.delete(params, :price)
      price when is_integer(price) and price == 0 -> Map.delete(params, :price)
      _ -> params
    end
  end

  @spec delete_product(String.t(), module()) :: :ok | {:error, String.t() | AppError.t()}
  def delete_product(id, repo \\ @default_repo) do
    repo.delete(id)
  end

  @spec list_products(module()) :: {:ok, [Product.t()]} | {:error, String.t() | AppError.t()}
  def list_products(repo \\ @default_repo) do
    repo.list()
  end

  @spec product_exists?(String.t(), module()) :: boolean()
  def product_exists?(id, repo \\ @default_repo) do
    repo.exists?(id)
  end
end
