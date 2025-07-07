defmodule QueryService.Application.Handlers.CategoryQueryHandler do
  @moduledoc """
  カテゴリクエリハンドラー

  カテゴリに関するクエリを処理し、読み取り専用データを返します
  """

  @behaviour QueryService.Application.Handlers.QueryHandler

  alias QueryService.Application.Queries.CategoryQueries.{
    GetCategory,
    GetCategoryWithProducts,
    ListCategories
  }

  alias QueryService.Infrastructure.Repositories.CategoryRepository, as: CategoryRepo
  alias QueryService.Infrastructure.Repositories.ProductRepository, as: ProductRepo

  @impl true
  def query_types do
    [GetCategory, ListCategories, GetCategoryWithProducts]
  end

  @impl true
  def handle_query(%GetCategory{} = query) do
    with :ok <- query.__struct__.validate(query) do
      case CategoryRepo.find_by_id(query.id) do
        {:ok, category} ->
          {:ok, format_category(category)}

        {:error, :not_found} ->
          {:error, "Category not found"}

        error ->
          error
      end
    end
  end

  def handle_query(%ListCategories{} = query) do
    with :ok <- query.__struct__.validate(query) do
      limit = query.limit || 20
      offset = query.offset || 0

      categories =
        CategoryRepo.list()
        |> apply_sorting(query.sort_by, query.sort_order)
        |> apply_pagination(limit, offset)
        |> Enum.map(fn category ->
          if query.include_product_count do
            {:ok, products} = ProductRepo.find_by_category_id(category.id)
            product_count = length(products)
            format_category_with_count(category, product_count)
          else
            format_category(category)
          end
        end)

      {:ok,
       %{
         categories: categories,
         total: length(categories),
         limit: limit,
         offset: offset
       }}
    end
  end

  def handle_query(%GetCategoryWithProducts{} = query) do
    with :ok <- query.__struct__.validate(query) do
      product_limit = query.product_limit || 20
      product_offset = query.product_offset || 0

      case CategoryRepo.find_by_id(query.id) do
        {:ok, category} ->
          products =
            ProductRepo.find_by_category_id(query.id)
            |> apply_pagination(product_limit, product_offset)
            |> Enum.map(&format_product/1)

          {:ok,
           %{
             category: format_category(category),
             products: products,
             products_total: length(products),
             product_limit: product_limit,
             product_offset: product_offset
           }}

        {:error, :not_found} ->
          {:error, "Category not found"}

        error ->
          error
      end
    end
  end

  def handle_query(_query) do
    {:error, "Unknown query"}
  end

  # プライベート関数

  defp format_category(category) do
    %{
      id: category.id,
      name: category.name,
      created_at: category.created_at,
      updated_at: category.updated_at
    }
  end

  defp format_category_with_count(category, count) do
    Map.put(format_category(category), :product_count, count)
  end

  defp format_product(product) do
    %{
      id: product.id,
      name: product.name,
      price: Decimal.to_string(product.price),
      category_id: product.category_id,
      created_at: product.created_at,
      updated_at: product.updated_at
    }
  end

  defp apply_sorting(categories, nil, _order), do: categories
  defp apply_sorting(categories, :name, :desc), do: Enum.sort_by(categories, & &1.name, :desc)
  defp apply_sorting(categories, :name, _), do: Enum.sort_by(categories, & &1.name, :asc)
  defp apply_sorting(categories, _, _), do: categories

  defp apply_pagination(items, limit, offset) do
    items
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end
end
