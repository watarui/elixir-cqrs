defmodule QueryService.Presentation.Grpc.ProductQueryServer do
  @moduledoc """
  Product Query gRPC Server Implementation
  """

  use GRPC.Server, service: Query.ProductQuery.Service

  alias QueryService.Infrastructure.Repositories.{ProductRepository, CategoryRepository}
  alias Shared.Errors.{AppError, GrpcErrorConverter}

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

  @spec get_product(Query.ProductQueryRequest.t(), GRPC.Server.Stream.t()) :: Query.ProductQueryResponse.t()
  def get_product(%Query.ProductQueryRequest{id: id}, _stream) do
    case ProductRepository.find_by_id(id) do
      {:error, :not_found} ->
        raise GrpcErrorConverter.to_rpc_error({:error, :not_found})

      {:ok, product} ->
        response = %Query.ProductQueryResponse{
          product: format_product(product)
        }

        response
    end
  end

  @spec get_product_by_name(Query.ProductByNameRequest.t(), GRPC.Server.Stream.t()) :: Query.ProductQueryResponse.t()
  def get_product_by_name(%Query.ProductByNameRequest{name: name}, _stream) do
    case ProductRepository.find_by_name(name) do
      {:error, :not_found} ->
        raise GrpcErrorConverter.to_rpc_error({:error, :not_found})

      {:ok, product} ->
        response = %Query.ProductQueryResponse{
          product: format_product(product)
        }

        response
    end
  end

  @spec list_products(Query.Empty.t(), GRPC.Server.Stream.t()) :: Query.ProductListResponse.t()
  def list_products(%Query.Empty{}, _stream) do
    case ProductRepository.list() do
      {:ok, products} ->
        response = %Query.ProductListResponse{
          products: Enum.map(products, &format_product/1)
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_products_by_category(Query.ProductByCategoryRequest.t(), GRPC.Server.Stream.t()) :: Query.ProductListResponse.t()
  def get_products_by_category(%Query.ProductByCategoryRequest{category_id: category_id}, _stream) do
    case ProductRepository.find_by_category_id(category_id) do
      {:ok, products} ->
        response = %Query.ProductListResponse{
          products: Enum.map(products, &format_product/1)
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec search_products(Query.ProductSearchRequest.t(), GRPC.Server.Stream.t()) :: Query.ProductListResponse.t()
  def search_products(%Query.ProductSearchRequest{search_term: search_term}, _stream) do
    case ProductRepository.search(search_term) do
      {:ok, products} ->
        response = %Query.ProductListResponse{
          products: Enum.map(products, &format_product/1)
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_products_by_price_range(
        %Query.ProductPriceRangeRequest{min_price: min_price, max_price: max_price},
        _stream
      ) do
    case ProductRepository.find_by_price_range(%{min: min_price, max: max_price}) do
      {:ok, products} ->
        response = %Query.ProductListResponse{
          products: Enum.map(products, &format_product/1)
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_products_paginated(
        %Query.ProductPaginationRequest{page: page, per_page: per_page},
        _stream
      ) do
    case ProductRepository.list_paginated(%{page: page, page_size: per_page}) do
      {:ok, {products, _total_count}} ->
        response = %Query.ProductListResponse{
          products: Enum.map(products, &format_product/1)
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_product_statistics(%Query.Empty{}, _stream) do
    case ProductRepository.get_statistics() do
      {:ok, stats} ->
        response = %Query.ProductStatisticsResponse{
          total_count: stats.total_count,
          has_products: stats.has_products,
          products_with_timestamps: stats.products_with_timestamps
        }

        response

      {:error, reason} ->
        {:error, reason}
    end
  end

  def product_exists(%Query.ProductExistsRequest{id: id}, _stream) do
    exists = ProductRepository.exists?(id)

    response = %Query.ProductExistsResponse{
      exists: exists
    }

    response
  end

  # プライベート関数

  defp format_product(product) do
    # Product Domain ModelにはCategory名が既に含まれている
    category =
      if product.category_name do
        %Query.Category{
          id: product.category_id,
          name: product.category_name,
          # カテゴリの詳細情報が必要な場合は別途取得
          created_at: 0,
          updated_at: 0
        }
      else
        nil
      end

    %Query.Product{
      id: product.id,
      name: product.name,
      price: product.price |> Decimal.to_float(),
      category_id: product.category_id,
      category: category,
      created_at: datetime_to_unix_timestamp(product.created_at),
      updated_at: datetime_to_unix_timestamp(product.updated_at)
    }
  end
end
