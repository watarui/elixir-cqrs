defmodule QueryService.Presentation.Grpc.CategoryQueryServer do
  @moduledoc """
  Category Query gRPC Server Implementation
  """

  use GRPC.Server, service: Query.CategoryQuery.Service

  alias QueryService.Infrastructure.Repositories.CategoryRepository

  def get_category(%Query.CategoryQueryRequest{id: id}, _stream) do
    case CategoryRepository.get_by_id(id) do
      nil ->
        {:error, "Category not found"}

      category ->
        response = %Query.CategoryQueryResponse{
          category: %Query.Category{
            id: category.id,
            name: category.name,
            created_at: category.inserted_at |> DateTime.to_unix(),
            updated_at: category.updated_at |> DateTime.to_unix()
          }
        }

        {:ok, response}
    end
  end

  def get_category_by_name(%Query.CategoryByNameRequest{name: name}, _stream) do
    case CategoryRepository.get_by_name(name) do
      nil ->
        {:error, "Category not found"}

      category ->
        response = %Query.CategoryQueryResponse{
          category: %Query.Category{
            id: category.id,
            name: category.name,
            created_at: category.inserted_at |> DateTime.to_unix(),
            updated_at: category.updated_at |> DateTime.to_unix()
          }
        }

        {:ok, response}
    end
  end

  def list_categories(%Query.Empty{}, _stream) do
    categories = CategoryRepository.list_all()

    response = %Query.CategoryListResponse{
      categories:
        Enum.map(categories, fn category ->
          %Query.Category{
            id: category.id,
            name: category.name,
            created_at: category.inserted_at |> DateTime.to_unix(),
            updated_at: category.updated_at |> DateTime.to_unix()
          }
        end)
    }

    {:ok, response}
  end

  def search_categories(%Query.CategorySearchRequest{search_term: search_term}, _stream) do
    categories = CategoryRepository.search(search_term)

    response = %Query.CategoryListResponse{
      categories:
        Enum.map(categories, fn category ->
          %Query.Category{
            id: category.id,
            name: category.name,
            created_at: category.inserted_at |> DateTime.to_unix(),
            updated_at: category.updated_at |> DateTime.to_unix()
          }
        end)
    }

    {:ok, response}
  end

  def list_categories_paginated(
        %Query.CategoryPaginationRequest{page: page, per_page: per_page},
        _stream
      ) do
    categories = CategoryRepository.list_paginated(page, per_page)

    response = %Query.CategoryListResponse{
      categories:
        Enum.map(categories, fn category ->
          %Query.Category{
            id: category.id,
            name: category.name,
            created_at: category.inserted_at |> DateTime.to_unix(),
            updated_at: category.updated_at |> DateTime.to_unix()
          }
        end)
    }

    {:ok, response}
  end

  def get_category_statistics(%Query.Empty{}, _stream) do
    stats = CategoryRepository.get_statistics()

    response = %Query.CategoryStatisticsResponse{
      total_count: stats.total_count,
      has_categories: stats.has_categories,
      categories_with_timestamps: stats.categories_with_timestamps
    }

    {:ok, response}
  end

  def category_exists(%Query.CategoryExistsRequest{id: id}, _stream) do
    exists = CategoryRepository.exists?(id)

    response = %Query.CategoryExistsResponse{
      exists: exists
    }

    {:ok, response}
  end
end
