defmodule QueryService.Infrastructure.Repositories.CategoryRepository do
  @moduledoc """
  Category Repository Implementation for Query Service
  """

  @behaviour QueryService.Domain.Repositories.CategoryRepository

  import Ecto.Query

  alias QueryService.Infrastructure.Database.Repo
  alias QueryService.Infrastructure.Database.Schemas.CategorySchema

  def get_by_id(id) do
    Repo.get(CategorySchema, id)
  end

  def get_by_name(name) do
    Repo.get_by(CategorySchema, name: name)
  end

  def list_all do
    Repo.all(CategorySchema)
  end

  def search(search_term) do
    query =
      from(c in CategorySchema,
        where: ilike(c.name, ^"%#{search_term}%"),
        order_by: c.name
      )

    Repo.all(query)
  end

  def list_paginated(page, per_page) do
    offset = (page - 1) * per_page

    query =
      from(c in CategorySchema,
        limit: ^per_page,
        offset: ^offset,
        order_by: c.name
      )

    Repo.all(query)
  end

  def get_statistics do
    total_query = from(c in CategorySchema, select: count(c.id))
    total_count = Repo.one(total_query)

    has_categories = total_count > 0

    timestamps_query =
      from(c in CategorySchema,
        where: not is_nil(c.inserted_at) and not is_nil(c.updated_at),
        select: count(c.id)
      )

    categories_with_timestamps = Repo.one(timestamps_query)

    %{
      total_count: total_count,
      has_categories: has_categories,
      categories_with_timestamps: categories_with_timestamps
    }
  end

  def exists?(id) do
    query = from(c in CategorySchema, where: c.id == ^id, select: count(c.id))
    Repo.one(query) > 0
  end
end
