defmodule CommandService.Application.Services.ProductService do
  @moduledoc """
  商品アプリケーションサービス

  商品に関するビジネスロジックとオーケストレーションを提供します
  """

  alias CommandService.Domain.Entities.Product
  alias CommandService.Domain.Logic.ProductLogic
  alias CommandService.Infrastructure.RepositoryContext
  alias Shared.Errors.AppError

  # リポジトリの取得（依存性注入対応）
  defp repo, do: RepositoryContext.product_repository()

  @spec create_product(map()) :: {:ok, Product.t()} | {:error, String.t() | AppError.t()}
  def create_product(params) do
    id = UUID.uuid4()

    # 純粋な関数でビジネスルールを検証
    with :ok <- validate_product_params(params),
         {:ok, product} <- Product.new(id, params[:name], params[:price], params[:category_id]) do
      repo().save(product)
    end
  end

  # 純粋な検証関数
  defp validate_product_params(params) do
    with :ok <- ProductLogic.validate_product_name_format(params[:name] || "") do
      ProductLogic.validate_non_zero_price(params[:price] || 0)
    end
  end

  @spec get_product(String.t()) ::
          {:ok, Product.t()} | {:error, :not_found | String.t() | AppError.t()}
  def get_product(id) do
    repo().find_by_id(id)
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
  @spec update_product(String.t(), map()) ::
          {:ok, Product.t()} | {:error, String.t() | AppError.t()}
  def update_product(id, params) do
    with {:ok, product} <- repo().find_by_id(id),
         # 純粋な関数でパラメータをフィルタリング
         filtered_params = ProductLogic.filter_update_params(params),
         # 純粋な関数でビジネスルールを適用
         {:ok, validated_params} <- ProductLogic.apply_price_update_rules(filtered_params),
         {:ok, updated_product} <- Product.update(product, validated_params),
         {:ok, saved_product} <- repo().update(updated_product) do
      # 変更検出（ピュア関数）
      changes = ProductLogic.detect_changes(product, saved_product)
      log_product_changes(id, changes)

      {:ok, saved_product}
    end
  end

  # 変更ログ記録（副作用）
  defp log_product_changes(_id, %{changes: changes}) when map_size(changes) > 0 do
    # ログ記録の実装（将来的に追加）
    :ok
  end

  defp log_product_changes(_id, _), do: :ok

  @spec delete_product(String.t()) :: :ok | {:error, String.t() | AppError.t()}
  def delete_product(id) do
    repo().delete(id)
  end

  @spec list_products() :: {:ok, [Product.t()]} | {:error, String.t() | AppError.t()}
  def list_products do
    repo().list()
  end

  @spec product_exists?(String.t()) :: boolean()
  def product_exists?(id) do
    repo().exists?(id)
  end
end
