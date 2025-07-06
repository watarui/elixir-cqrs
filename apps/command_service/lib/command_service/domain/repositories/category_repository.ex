defmodule CommandService.Domain.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリリポジトリのインターフェース

  カテゴリの永続化に関する抽象化を提供します
  """

  alias CommandService.Domain.Entities.Category

  @type t :: module()

  @callback save(Category.t()) :: {:ok, Category.t()} | {:error, String.t()}
  @callback find_by_id(String.t()) ::
              {:ok, Category.t()} | {:error, :not_found} | {:error, String.t()}
  @callback find_by_name(String.t()) ::
              {:ok, Category.t()} | {:error, :not_found} | {:error, String.t()}
  @callback update(Category.t()) :: {:ok, Category.t()} | {:error, String.t()}
  @callback delete(String.t()) :: :ok | {:error, String.t()}
  @callback exists?(String.t()) :: boolean()
  @callback list() :: {:ok, [Category.t()]} | {:error, String.t()}
end
