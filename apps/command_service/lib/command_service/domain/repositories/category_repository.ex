defmodule CommandService.Domain.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリリポジトリのインターフェース

  カテゴリの永続化に関する抽象化を提供します
  Shared.Domain.Repositoryの基本インターフェースを拡張し、
  カテゴリ特有の操作を追加します。
  """

  alias CommandService.Domain.Entities.Category
  alias Shared.Errors.AppError

  # 基本リポジトリインターフェースを継承しない（インターフェース定義のみ）
  # @behaviour Shared.Domain.Repository

  @type t :: module()

  # 基本操作の型を具体化
  @callback save(Category.t()) :: {:ok, Category.t()} | {:error, AppError.t()}
  @callback find_by_id(String.t()) :: {:ok, Category.t()} | {:error, AppError.t()}
  @callback update(Category.t()) :: {:ok, Category.t()} | {:error, AppError.t()}
  @callback delete(String.t()) :: :ok | {:error, AppError.t()}
  @callback list() :: {:ok, [Category.t()]} | {:error, AppError.t()}
  @callback exists?(String.t()) :: boolean()
  @callback count(conditions :: map()) :: {:ok, non_neg_integer()} | {:error, AppError.t()}
  @callback transaction(fun :: function()) :: {:ok, any()} | {:error, AppError.t()}

  # カテゴリ特有の操作
  @callback find_by_name(String.t()) :: {:ok, Category.t()} | {:error, AppError.t()}
  @callback has_products?(String.t()) :: boolean()

  # オプショナルコールバック
  @optional_callbacks [count: 1, transaction: 1]
end
