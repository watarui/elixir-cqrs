defmodule QueryService.Infrastructure.Repositories.ProductRepository do
  @moduledoc """
  Product Repository Implementation for Query Service
  """

  @behaviour QueryService.Domain.Repositories.ProductRepository

  import Ecto.Query

  alias QueryService.Infrastructure.Database.Repo
  alias QueryService.Infrastructure.Database.Schemas.ProductSchema

  def get_by_id(id) do
    Repo.get(ProductSchema, id)
  end

  def get_by_name(name) do
    Repo.get_by(ProductSchema, name: name)
  end

  def list_all do
    Repo.all(ProductSchema)
  end

  def get_by_category(category_id) do
    query =
      from(p in ProductSchema,
        where: p.category_id == ^category_id,
        order_by: p.name
      )

    Repo.all(query)
  end

  def search(search_term) do
    query =
      from(p in ProductSchema,
        where: ilike(p.name, ^"%#{search_term}%"),
        order_by: p.name
      )

    Repo.all(query)
  end

  def get_by_price_range(min_price, max_price) do
    query =
      from(p in ProductSchema,
        where: p.price >= ^min_price and p.price <= ^max_price,
        order_by: p.price
      )

    Repo.all(query)
  end

  def list_paginated(page, per_page) do
    offset = (page - 1) * per_page

    query =
      from(p in ProductSchema,
        limit: ^per_page,
        offset: ^offset,
        order_by: p.name
      )

    Repo.all(query)
  end

  def get_statistics do
    total_query = from(p in ProductSchema, select: count(p.id))
    total_count = Repo.one(total_query)

    has_products = total_count > 0

    price_stats_query =
      from(p in ProductSchema,
        select: %{
          avg_price: avg(p.price),
          min_price: min(p.price),
          max_price: max(p.price)
        }
      )

    price_stats = Repo.one(price_stats_query)

    timestamps_query =
      from(p in ProductSchema,
        where: not is_nil(p.inserted_at) and not is_nil(p.updated_at),
        select: count(p.id)
      )

    products_with_timestamps = Repo.one(timestamps_query)

    %{
      total_count: total_count,
      has_products: has_products,
      average_price:
        if(price_stats.avg_price, do: Decimal.to_float(price_stats.avg_price), else: 0.0),
      min_price:
        if(price_stats.min_price, do: Decimal.to_float(price_stats.min_price), else: 0.0),
      max_price:
        if(price_stats.max_price, do: Decimal.to_float(price_stats.max_price), else: 0.0),
      products_with_timestamps: products_with_timestamps
    }
  end

  def exists?(id) do
    query = from(p in ProductSchema, where: p.id == ^id, select: count(p.id))
    Repo.one(query) > 0
  end
end
