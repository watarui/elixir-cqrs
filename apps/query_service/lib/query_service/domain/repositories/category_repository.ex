defmodule QueryService.Domain.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリクエリリポジトリのインターフェース

  カテゴリの読み取り専用操作に関する抽象化を提供します
  """

  alias QueryService.Domain.Models.Category

  @type t :: module()
  @type pagination_opts :: %{
          page: integer(),
          page_size: integer()
        }

  @callback find_by_id(String.t()) ::
              {:ok, Category.t()} | {:error, :not_found} | {:error, String.t()}
  @callback find_by_name(String.t()) ::
              {:ok, Category.t()} | {:error, :not_found} | {:error, String.t()}
  @callback list() :: {:ok, [Category.t()]} | {:error, String.t()}
  @callback list_paginated(pagination_opts()) ::
              {:ok, {[Category.t()], integer()}} | {:error, String.t()}
  @callback search(String.t()) :: {:ok, [Category.t()]} | {:error, String.t()}
  @callback exists?(String.t()) :: boolean()
  @callback count() :: {:ok, integer()} | {:error, String.t()}
  @callback get_statistics() :: {:ok, map()} | {:error, String.t()}
end
