defmodule QueryService.Presentation.Grpc.ProductQueryServer do
  @moduledoc """
  Product Query gRPC Server Implementation
  """

  use GRPC.Server, service: Query.ProductQuery.Service

  alias QueryService.Infrastructure.Repositories.{ProductRepository, CategoryRepository}

  def get_product(%Query.ProductQueryRequest{id: id}, _stream) do
    case ProductRepository.get_by_id(id) do
      nil ->
        {:error, "Product not found"}

      product ->
        response = %Query.ProductQueryResponse{
          product: format_product(product)
        }

        {:ok, response}
    end
  end

  def get_product_by_name(%Query.ProductByNameRequest{name: name}, _stream) do
    case ProductRepository.get_by_name(name) do
      nil ->
        {:error, "Product not found"}

      product ->
        response = %Query.ProductQueryResponse{
          product: format_product(product)
        }

        {:ok, response}
    end
  end

  def list_products(%Query.Empty{}, _stream) do
    products = ProductRepository.list_all()

    response = %Query.ProductListResponse{
      products: Enum.map(products, &format_product/1)
    }

    {:ok, response}
  end

  def get_products_by_category(%Query.ProductByCategoryRequest{category_id: category_id}, _stream) do
    products = ProductRepository.get_by_category(category_id)

    response = %Query.ProductListResponse{
      products: Enum.map(products, &format_product/1)
    }

    {:ok, response}
  end

  def search_products(%Query.ProductSearchRequest{search_term: search_term}, _stream) do
    products = ProductRepository.search(search_term)

    response = %Query.ProductListResponse{
      products: Enum.map(products, &format_product/1)
    }

    {:ok, response}
  end

  def get_products_by_price_range(
        %Query.ProductPriceRangeRequest{min_price: min_price, max_price: max_price},
        _stream
      ) do
    products = ProductRepository.get_by_price_range(min_price, max_price)

    response = %Query.ProductListResponse{
      products: Enum.map(products, &format_product/1)
    }

    {:ok, response}
  end

  def list_products_paginated(
        %Query.ProductPaginationRequest{page: page, per_page: per_page},
        _stream
      ) do
    products = ProductRepository.list_paginated(page, per_page)

    response = %Query.ProductListResponse{
      products: Enum.map(products, &format_product/1)
    }

    {:ok, response}
  end

  def get_product_statistics(%Query.Empty{}, _stream) do
    stats = ProductRepository.get_statistics()

    response = %Query.ProductStatisticsResponse{
      total_count: stats.total_count,
      has_products: stats.has_products,
      average_price: stats.average_price,
      min_price: stats.min_price,
      max_price: stats.max_price,
      products_with_timestamps: stats.products_with_timestamps
    }

    {:ok, response}
  end

  def product_exists(%Query.ProductExistsRequest{id: id}, _stream) do
    exists = ProductRepository.exists?(id)

    response = %Query.ProductExistsResponse{
      exists: exists
    }

    {:ok, response}
  end

  # プライベート関数

  defp format_product(product) do
    category = CategoryRepository.get_by_id(product.category_id)

    %Query.Product{
      id: product.id,
      name: product.name,
      price: product.price |> Decimal.to_float(),
      category_id: product.category_id,
      category: if(category, do: format_category(category), else: nil),
      created_at: product.inserted_at |> DateTime.to_unix(),
      updated_at: product.updated_at |> DateTime.to_unix()
    }
  end

  defp format_category(category) do
    %Query.Category{
      id: category.id,
      name: category.name,
      created_at: category.inserted_at |> DateTime.to_unix(),
      updated_at: category.updated_at |> DateTime.to_unix()
    }
  end
end
