defmodule QueryService.Infrastructure.Repositories.ProductRepository do
  @moduledoc """
  Product Repository Implementation for Query Service
  """

  @behaviour QueryService.Domain.Repositories.ProductRepository

  import Ecto.Query

  alias QueryService.Infrastructure.Database.Repo
  alias QueryService.Infrastructure.Database.Schemas.{ProductSchema, CategorySchema}
  alias QueryService.Domain.Models.Product

  @impl true
  def find_by_id(id) when is_binary(id) do
    query =
      from(p in ProductSchema,
        left_join: c in CategorySchema,
        on: p.category_id == c.id,
        where: p.id == ^id,
        select: {p, c.name}
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      {schema, category_name} -> {:ok, schema_to_model(schema, category_name)}
    end
  end

  @impl true
  def find_by_name(name) when is_binary(name) do
    query =
      from(p in ProductSchema,
        left_join: c in CategorySchema,
        on: p.category_id == c.id,
        where: p.name == ^name,
        select: {p, c.name}
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      {schema, category_name} -> {:ok, schema_to_model(schema, category_name)}
    end
  end

  @impl true
  def list do
    query =
      from(p in ProductSchema,
        left_join: c in CategorySchema,
        on: p.category_id == c.id,
        select: {p, c.name},
        order_by: p.name
      )

    results = Repo.all(query)

    models =
      Enum.map(results, fn {schema, category_name} -> schema_to_model(schema, category_name) end)

    {:ok, models}
  end

  @impl true
  def find_by_category_id(category_id) when is_binary(category_id) do
    query =
      from(p in ProductSchema,
        left_join: c in CategorySchema,
        on: p.category_id == c.id,
        where: p.category_id == ^category_id,
        select: {p, c.name},
        order_by: p.name
      )

    results = Repo.all(query)

    models =
      Enum.map(results, fn {schema, category_name} -> schema_to_model(schema, category_name) end)

    {:ok, models}
  end

  @impl true
  def search(search_term) when is_binary(search_term) do
    query =
      from(p in ProductSchema,
        left_join: c in CategorySchema,
        on: p.category_id == c.id,
        where: ilike(p.name, ^"%#{search_term}%"),
        select: {p, c.name},
        order_by: p.name
      )

    results = Repo.all(query)

    models =
      Enum.map(results, fn {schema, category_name} -> schema_to_model(schema, category_name) end)

    {:ok, models}
  end

  @impl true
  def find_by_price_range(%{min: min_price, max: max_price}) do
    query =
      from(p in ProductSchema,
        left_join: c in CategorySchema,
        on: p.category_id == c.id,
        where: p.price >= ^(min_price || 0) and p.price <= ^(max_price || 999_999),
        select: {p, c.name},
        order_by: p.price
      )

    results = Repo.all(query)

    models =
      Enum.map(results, fn {schema, category_name} -> schema_to_model(schema, category_name) end)

    {:ok, models}
  end

  @impl true
  def list_paginated(%{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size

    query =
      from(p in ProductSchema,
        left_join: c in CategorySchema,
        on: p.category_id == c.id,
        select: {p, c.name},
        limit: ^page_size,
        offset: ^offset,
        order_by: p.name
      )

    results = Repo.all(query)

    models =
      Enum.map(results, fn {schema, category_name} -> schema_to_model(schema, category_name) end)

    total_count = count_all()
    {:ok, {models, total_count}}
  end

  @impl true
  def count do
    total_count = count_all()
    {:ok, total_count}
  end

  @impl true
  def count_by_category(category_id) when is_binary(category_id) do
    query = from(p in ProductSchema, where: p.category_id == ^category_id, select: count(p.id))
    count = Repo.one(query)
    {:ok, count}
  end

  @impl true
  def get_statistics do
    total_count = count_all()
    has_products = total_count > 0

    timestamps_query =
      from(p in ProductSchema,
        where: not is_nil(p.inserted_at) and not is_nil(p.updated_at),
        select: count(p.id)
      )

    products_with_timestamps = Repo.one(timestamps_query)

    statistics = %{
      total_count: total_count,
      has_products: has_products,
      products_with_timestamps: products_with_timestamps
    }

    {:ok, statistics}
  end

  @impl true
  def get_price_statistics do
    price_stats_query =
      from(p in ProductSchema,
        select: %{
          avg_price: avg(p.price),
          min_price: min(p.price),
          max_price: max(p.price)
        }
      )

    price_stats = Repo.one(price_stats_query)

    statistics = %{
      average_price:
        if(price_stats.avg_price, do: Decimal.to_float(price_stats.avg_price), else: 0.0),
      min_price:
        if(price_stats.min_price, do: Decimal.to_float(price_stats.min_price), else: 0.0),
      max_price: if(price_stats.max_price, do: Decimal.to_float(price_stats.max_price), else: 0.0)
    }

    {:ok, statistics}
  end

  @impl true
  def exists?(id) do
    query = from(p in ProductSchema, where: p.id == ^id, select: count(p.id))
    Repo.one(query) > 0
  end

  # プライベートヘルパー関数
  defp count_all do
    query = from(p in ProductSchema, select: count(p.id))
    Repo.one(query)
  end

  defp schema_to_model(schema, category_name) do
    Product.new(schema.id, schema.name, schema.price, schema.category_id)
    |> Product.with_category_name(category_name)
    |> Product.with_timestamps(schema.inserted_at, schema.updated_at)
  end
end
