defmodule CommandService.Domain.Repositories.ProductRepository do
  @moduledoc """
  商品リポジトリのインターフェース

  商品の永続化に関する抽象化を提供します
  """

  alias CommandService.Domain.Entities.Product

  @type t :: module()

  @callback save(Product.t()) :: {:ok, Product.t()} | {:error, String.t()}
  @callback find_by_id(String.t()) ::
              {:ok, Product.t()} | {:error, :not_found} | {:error, String.t()}
  @callback find_by_name(String.t()) ::
              {:ok, Product.t()} | {:error, :not_found} | {:error, String.t()}
  @callback find_by_category_id(String.t()) :: {:ok, [Product.t()]} | {:error, String.t()}
  @callback update(Product.t()) :: {:ok, Product.t()} | {:error, String.t()}
  @callback delete(String.t()) :: :ok | {:error, String.t()}
  @callback exists?(String.t()) :: boolean()
  @callback list() :: {:ok, [Product.t()]} | {:error, String.t()}
end
