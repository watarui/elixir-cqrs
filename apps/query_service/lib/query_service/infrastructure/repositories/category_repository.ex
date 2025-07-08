defmodule QueryService.Infrastructure.Repositories.CategoryRepository do
  @moduledoc """
  Category Repository Implementation for Query Service
  """

  @behaviour QueryService.Domain.Repositories.CategoryRepository

  import Ecto.Query

  alias QueryService.Domain.Models.Category
  alias QueryService.Infrastructure.Database.Repo
  alias QueryService.Infrastructure.Database.Schemas.CategorySchema
  alias QueryService.Infrastructure.Repositories.CachedRepository

  @impl true
  def find_by_id(id) when is_binary(id) do
    CachedRepository.cached_find_by_id(__MODULE__, id)
  end

  # キャッシュを使わない内部実装
  def find_by_id_uncached(id) when is_binary(id) do
    case Repo.get(CategorySchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_model(schema)}
    end
  end

  @impl true
  def find_by_name(name) when is_binary(name) do
    case Repo.get_by(CategorySchema, name: name) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_model(schema)}
    end
  end

  @impl true
  def list do
    CachedRepository.cached_list(__MODULE__)
  end

  # キャッシュを使わない内部実装
  def list_uncached do
    schemas = Repo.all(CategorySchema)
    models = Enum.map(schemas, &schema_to_model/1)
    {:ok, models}
  end

  @impl true
  def search(search_term) when is_binary(search_term) do
    query =
      from(c in CategorySchema,
        where: ilike(c.name, ^"%#{search_term}%"),
        order_by: c.name
      )

    schemas = Repo.all(query)
    models = Enum.map(schemas, &schema_to_model/1)
    {:ok, models}
  end

  @impl true
  def list_paginated(%{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size

    query =
      from(c in CategorySchema,
        limit: ^page_size,
        offset: ^offset,
        order_by: c.name
      )

    schemas = Repo.all(query)
    models = Enum.map(schemas, &schema_to_model/1)

    total_count = count_all()
    {:ok, {models, total_count}}
  end

  @impl true
  def count do
    total_count = count_all()
    {:ok, total_count}
  end

  @impl true
  def get_statistics do
    total_count = count_all()
    has_categories = total_count > 0

    timestamps_query =
      from(c in CategorySchema,
        where: not is_nil(c.inserted_at) and not is_nil(c.updated_at),
        select: count(c.id)
      )

    categories_with_timestamps = Repo.one(timestamps_query)

    statistics = %{
      total_count: total_count,
      has_categories: has_categories,
      categories_with_timestamps: categories_with_timestamps
    }

    {:ok, statistics}
  end

  # プライベートヘルパー関数
  defp count_all do
    total_query = from(c in CategorySchema, select: count(c.id))
    Repo.one(total_query)
  end

  @impl true
  def exists?(id) do
    query = from(c in CategorySchema, where: c.id == ^id, select: count(c.id))
    Repo.one(query) > 0
  end

  @doc """
  ルートカテゴリ（parent_idがnilのカテゴリ）を取得する
  """
  def find_root_categories do
    query = from(c in CategorySchema, where: is_nil(c.parent_id))

    categories =
      Repo.all(query)
      |> Enum.map(&schema_to_model/1)

    categories
  end

  @doc """
  特定の親カテゴリに属する子カテゴリを取得する
  """
  def find_by_parent_id(parent_id) do
    query = from(c in CategorySchema, where: c.parent_id == ^parent_id)

    Repo.all(query)
    |> Enum.map(&schema_to_model/1)
  end

  # Schema to Domain Model変換
  defp schema_to_model(schema) do
    # スキーマから必要なフィールドを取得してマップを作成
    %{
      id: schema.id,
      name: schema.name,
      parent_id: schema.parent_id,
      level: Map.get(schema, :level, 0),
      is_active: Map.get(schema, :is_active, true),
      created_at: to_datetime(schema.inserted_at),
      updated_at: to_datetime(schema.updated_at)
    }
  end

  # タイムスタンプ変換ヘルパー関数
  defp to_datetime(nil), do: nil
  defp to_datetime(%NaiveDateTime{} = naive_dt), do: DateTime.from_naive!(naive_dt, "Etc/UTC")
  defp to_datetime(%DateTime{} = dt), do: dt
end
