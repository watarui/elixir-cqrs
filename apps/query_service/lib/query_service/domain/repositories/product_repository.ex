defmodule QueryService.Domain.Repositories.ProductRepository do
  @moduledoc """
  商品クエリリポジトリのインターフェース

  商品の読み取り専用操作に関する抽象化を提供します
  """

  alias QueryService.Domain.Models.Product

  @type t :: module()
  @type pagination_opts :: %{
          page: integer(),
          page_size: integer()
        }
  @type price_range :: %{
          min: Decimal.t() | nil,
          max: Decimal.t() | nil
        }

  @callback find_by_id(String.t()) ::
              {:ok, Product.t()} | {:error, :not_found} | {:error, String.t()}
  @callback find_by_name(String.t()) ::
              {:ok, Product.t()} | {:error, :not_found} | {:error, String.t()}
  @callback list() :: {:ok, [Product.t()]} | {:error, String.t()}
  @callback list_paginated(pagination_opts()) ::
              {:ok, {[Product.t()], integer()}} | {:error, String.t()}
  @callback search(String.t()) :: {:ok, [Product.t()]} | {:error, String.t()}
  @callback find_by_category_id(String.t()) :: {:ok, [Product.t()]} | {:error, String.t()}
  @callback find_by_price_range(price_range()) :: {:ok, [Product.t()]} | {:error, String.t()}
  @callback exists?(String.t()) :: boolean()
  @callback count() :: {:ok, integer()} | {:error, String.t()}
  @callback count_by_category(String.t()) :: {:ok, integer()} | {:error, String.t()}
  @callback get_statistics() :: {:ok, map()} | {:error, String.t()}
  @callback get_price_statistics() :: {:ok, map()} | {:error, String.t()}
end
