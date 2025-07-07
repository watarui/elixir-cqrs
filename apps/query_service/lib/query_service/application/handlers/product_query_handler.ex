defmodule QueryService.Application.Handlers.ProductQueryHandler do
  @moduledoc """
  商品クエリハンドラー

  商品に関するクエリを処理し、読み取り専用データを返します
  """

  @behaviour QueryService.Application.Handlers.QueryHandler

  alias QueryService.Application.Queries.ProductQueries.{
    GetProduct,
    ListProducts,
    SearchProducts,
    GetProductsByCategory
  }

  alias QueryService.Infrastructure.Repositories.ProductRepository, as: ProductRepo
  alias QueryService.Infrastructure.Repositories.CategoryRepository, as: CategoryRepo

  @impl true
  def query_types do
    [GetProduct, ListProducts, SearchProducts, GetProductsByCategory]
  end

  @impl true
  def handle_query(%GetProduct{} = query) do
    with :ok <- query.__struct__.validate(query) do
      case ProductRepo.find_by_id(query.id) do
        {:ok, product} ->
          {:ok, format_product(product)}

        {:error, :not_found} ->
          {:error, "Product not found"}

        error ->
          error
      end
    end
  end

  def handle_query(%ListProducts{} = query) do
    with :ok <- query.__struct__.validate(query) do
      limit = query.limit || 20
      offset = query.offset || 0

      products =
        if query.category_id do
          ProductRepo.find_by_category_id(query.category_id)
        else
          ProductRepo.list()
        end

      products =
        products
        |> apply_sorting(query.sort_by, query.sort_order)
        |> apply_pagination(limit, offset)
        |> Enum.map(&format_product/1)

      {:ok,
       %{
         products: products,
         total: length(products),
         limit: limit,
         offset: offset
       }}
    end
  end

  def handle_query(%SearchProducts{} = query) do
    with :ok <- query.__struct__.validate(query) do
      limit = query.limit || 20
      offset = query.offset || 0

      {:ok, all_products} = ProductRepo.list()

      products =
        all_products
        |> filter_by_search_term(query.search_term)
        |> filter_by_category(query.category_id)
        |> filter_by_price_range(query.min_price, query.max_price)
        |> apply_pagination(limit, offset)
        |> Enum.map(&format_product/1)

      {:ok,
       %{
         products: products,
         total: length(products),
         search_term: query.search_term,
         limit: limit,
         offset: offset
       }}
    end
  end

  def handle_query(%GetProductsByCategory{} = query) do
    with :ok <- query.__struct__.validate(query) do
      limit = query.limit || 20
      offset = query.offset || 0

      case CategoryRepo.find_by_id(query.category_id) do
        {:ok, category} ->
          products =
            ProductRepo.find_by_category_id(query.category_id)
            |> apply_pagination(limit, offset)
            |> Enum.map(&format_product/1)

          {:ok,
           %{
             category: format_category(category),
             products: products,
             total: length(products),
             limit: limit,
             offset: offset
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

  defp format_category(category) do
    %{
      id: category.id,
      name: category.name,
      created_at: category.created_at,
      updated_at: category.updated_at
    }
  end

  defp apply_sorting(products, nil, _order), do: products
  defp apply_sorting(products, :name, :desc), do: Enum.sort_by(products, & &1.name, :desc)
  defp apply_sorting(products, :name, _), do: Enum.sort_by(products, & &1.name, :asc)
  defp apply_sorting(products, :price, :desc), do: Enum.sort_by(products, & &1.price, :desc)
  defp apply_sorting(products, :price, _), do: Enum.sort_by(products, & &1.price, :asc)
  defp apply_sorting(products, _, _), do: products

  defp apply_pagination(products, limit, offset) do
    products
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  defp filter_by_search_term(products, search_term) do
    term = String.downcase(search_term)

    Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name), term)
    end)
  end

  defp filter_by_category(products, nil), do: products

  defp filter_by_category(products, category_id) do
    Enum.filter(products, fn product ->
      product.category_id == category_id
    end)
  end

  defp filter_by_price_range(products, nil, nil), do: products

  defp filter_by_price_range(products, min_price, nil) do
    Enum.filter(products, fn product ->
      Decimal.compare(product.price, min_price) != :lt
    end)
  end

  defp filter_by_price_range(products, nil, max_price) do
    Enum.filter(products, fn product ->
      Decimal.compare(product.price, max_price) != :gt
    end)
  end

  defp filter_by_price_range(products, min_price, max_price) do
    Enum.filter(products, fn product ->
      Decimal.compare(product.price, min_price) != :lt &&
        Decimal.compare(product.price, max_price) != :gt
    end)
  end
end
