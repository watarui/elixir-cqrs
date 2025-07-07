defmodule CommandService.Domain.Repositories.ProductRepository do
  @moduledoc """
  商品リポジトリのインターフェース

  商品の永続化に関する抽象化を提供します
  Shared.Domain.Repositoryの基本インターフェースを拡張し、
  商品特有の操作を追加します。
  """

  alias CommandService.Domain.Entities.Product
  alias Shared.Errors.AppError

  # 基本リポジトリインターフェースを継承しない（インターフェース定義のみ）
  # @behaviour Shared.Domain.Repository

  @type t :: module()

  # 基本操作の型を具体化
  @callback save(Product.t()) :: {:ok, Product.t()} | {:error, AppError.t()}
  @callback find_by_id(String.t()) :: {:ok, Product.t()} | {:error, AppError.t()}
  @callback update(Product.t()) :: {:ok, Product.t()} | {:error, AppError.t()}
  @callback delete(String.t()) :: :ok | {:error, AppError.t()}
  @callback list() :: {:ok, [Product.t()]} | {:error, AppError.t()}
  @callback exists?(String.t()) :: boolean()
  @callback count(conditions :: map()) :: {:ok, non_neg_integer()} | {:error, AppError.t()}
  @callback transaction(fun :: function()) :: {:ok, any()} | {:error, AppError.t()}

  # 商品特有の操作
  @callback find_by_name(String.t()) :: {:ok, Product.t()} | {:error, AppError.t()}
  @callback find_by_category_id(String.t()) :: {:ok, [Product.t()]} | {:error, AppError.t()}
  @callback find_by_price_range(min_price :: Decimal.t(), max_price :: Decimal.t()) ::
              {:ok, [Product.t()]} | {:error, AppError.t()}
  @callback search(keyword :: String.t()) :: {:ok, [Product.t()]} | {:error, AppError.t()}
  @callback paginate(page :: pos_integer(), per_page :: pos_integer()) ::
              {:ok, {[Product.t()], non_neg_integer()}} | {:error, AppError.t()}

  # オプショナルコールバック
  @optional_callbacks [search: 1, paginate: 2, count: 1, transaction: 1]
end
