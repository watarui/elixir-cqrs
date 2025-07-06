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

  @spec update_product(String.t(), map()) :: {:ok, Product.t()} | {:error, String.t()}
  def update_product(id, params) do
    with {:ok, product} <- @repo.find_by_id(id),
         {:ok, updated_product} <- Product.update(product, params),
         {:ok, saved_product} <- @repo.update(updated_product) do
      {:ok, saved_product}
    end
  end

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
