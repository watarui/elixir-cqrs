defmodule QueryService.Presentation.Grpc.CategoryQueryServer do
  @moduledoc """
  Category Query gRPC Server Implementation
  """

  use GRPC.Server, service: Query.CategoryQuery.Service

  alias QueryService.Infrastructure.Repositories.CategoryRepository

  # Helper function to convert DateTime to Unix timestamp
  defp datetime_to_unix_timestamp(%DateTime{} = datetime) do
    DateTime.to_unix(datetime)
  end

  defp datetime_to_unix_timestamp(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end

  defp datetime_to_unix_timestamp(nil), do: 0

  def get_category(%Query.CategoryQueryRequest{id: id}, _stream) do
    case CategoryRepository.find_by_id(id) do
      {:error, :not_found} ->
        {:error, "Category not found"}

      {:ok, category} ->
        response = %Query.CategoryQueryResponse{
          category: %Query.Category{
            id: category.id,
            name: category.name,
            created_at: datetime_to_unix_timestamp(category.created_at),
            updated_at: datetime_to_unix_timestamp(category.updated_at)
          }
        }

        response
    end
  end

  def get_category_by_name(%Query.CategoryByNameRequest{name: name}, _stream) do
    case CategoryRepository.find_by_name(name) do
      {:error, :not_found} ->
        {:error, "Category not found"}

      {:ok, category} ->
        response = %Query.CategoryQueryResponse{
          category: %Query.Category{
            id: category.id,
            name: category.name,
            created_at: datetime_to_unix_timestamp(category.created_at),
            updated_at: datetime_to_unix_timestamp(category.updated_at)
          }
        }

        response
    end
  end

  def list_categories(%Query.Empty{}, _stream) do
    case CategoryRepository.list() do
      {:ok, categories} ->
        response = %Query.CategoryListResponse{
          categories:
            Enum.map(categories, fn category ->
              %Query.Category{
                id: category.id,
                name: category.name,
                created_at: datetime_to_unix_timestamp(category.created_at),
                updated_at: datetime_to_unix_timestamp(category.updated_at)
              }
            end)
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  def search_categories(%Query.CategorySearchRequest{search_term: search_term}, _stream) do
    case CategoryRepository.search(search_term) do
      {:ok, categories} ->
        response = %Query.CategoryListResponse{
          categories:
            Enum.map(categories, fn category ->
              %Query.Category{
                id: category.id,
                name: category.name,
                created_at: datetime_to_unix_timestamp(category.created_at),
                updated_at: datetime_to_unix_timestamp(category.updated_at)
              }
            end)
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_categories_paginated(
        %Query.CategoryPaginationRequest{page: page, per_page: per_page},
        _stream
      ) do
    case CategoryRepository.list_paginated(%{page: page, page_size: per_page}) do
      {:ok, {categories, _total_count}} ->
        response = %Query.CategoryListResponse{
          categories:
            Enum.map(categories, fn category ->
              %Query.Category{
                id: category.id,
                name: category.name,
                created_at: datetime_to_unix_timestamp(category.created_at),
                updated_at: datetime_to_unix_timestamp(category.updated_at)
              }
            end)
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_category_statistics(%Query.Empty{}, _stream) do
    case CategoryRepository.get_statistics() do
      {:ok, stats} ->
        response = %Query.CategoryStatisticsResponse{
          total_count: stats.total_count,
          has_categories: stats.has_categories,
          categories_with_timestamps: stats.categories_with_timestamps
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  def category_exists(%Query.CategoryExistsRequest{id: id}, _stream) do
    exists = CategoryRepository.exists?(id)

    response = %Query.CategoryExistsResponse{
      exists: exists
    }

    response
  end
end
