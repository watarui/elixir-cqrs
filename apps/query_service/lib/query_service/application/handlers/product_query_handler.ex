defmodule QueryService.Application.Handlers.ProductQueryHandler do
  @moduledoc """
  商品クエリハンドラー

  商品に関するクエリを処理し、読み取り専用データを返します
  """

  @behaviour QueryService.Application.Handlers.QueryHandler

  alias QueryService.Application.Queries.ProductQueries.{
    GetProduct,
    GetProductsByCategory,
    ListProducts,
    SearchProducts
  }

  alias QueryService.Infrastructure.Repositories.CategoryRepository, as: CategoryRepo
  alias QueryService.Infrastructure.Repositories.ProductRepository, as: ProductRepo

  @impl true
  def query_types do
    [GetProduct, ListProducts, SearchProducts, GetProductsByCategory]
  end

  # handleメソッドの実装（test_support_queriesのクエリを処理）
  def handle(%{__struct__: module} = query) do
    # test_support_queriesのクエリモジュールに対応
    case module do
      QueryService.Application.Queries.GetProductQuery ->
        handle_get_product_query(query)

      QueryService.Application.Queries.ListProductsQuery ->
        handle_list_products_query(query)

      QueryService.Application.Queries.SearchProductsQuery ->
        handle_search_products_query(query)

      QueryService.Application.Queries.GetProductsByCategoryQuery ->
        handle_get_products_by_category_query(query)

      _ ->
        # 既存のクエリはhandle_queryに委譲
        handle_query(query)
    end
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

  # 新しいクエリモジュールのハンドラー実装
  defp handle_get_product_query(query) do
    case ProductRepo.find_by_id(query.id) do
      {:ok, product} ->
        result = format_product(product)

        result =
          if query.include_category && product.category_id do
            case CategoryRepo.find_by_id(product.category_id) do
              {:ok, category} -> Map.put(result, :category, format_category(category))
              _ -> result
            end
          else
            result
          end

        {:ok, result}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp handle_list_products_query(query) do
    products = ProductRepo.list()

    # フィルタリング
    products =
      if query.min_price || query.max_price do
        filter_by_price_range(products, query.min_price, query.max_price)
      else
        products
      end

    products =
      if query.availability do
        Enum.filter(products, &(&1.is_available == query.availability))
      else
        products
      end

    # ソート
    products =
      apply_sorting(products, String.to_atom(query.sort_by), String.to_atom(query.sort_order))

    # ページネーション
    total_count = length(products)
    products = apply_pagination(products, query.page_size, (query.page - 1) * query.page_size)

    {:ok,
     %{
       data: Enum.map(products, &format_product/1),
       metadata: %{
         page: query.page,
         page_size: query.page_size,
         total_count: total_count,
         total_pages: ceil(total_count / query.page_size)
       }
     }}
  end

  defp handle_search_products_query(query) do
    products = ProductRepo.list()

    # 検索フィルター
    products = filter_by_search_term(products, query.search_term)

    # カテゴリフィルター
    products =
      if query.category_id do
        filter_by_category(products, query.category_id)
      else
        products
      end

    # 価格フィルター
    products =
      if query.min_price || query.max_price do
        filter_by_price_range(products, query.min_price, query.max_price)
      else
        products
      end

    # ページネーション
    page = query.page || 1
    page_size = query.page_size || 20
    products = apply_pagination(products, page_size, (page - 1) * page_size)

    {:ok, %{data: Enum.map(products, &format_product/1)}}
  end

  defp handle_get_products_by_category_query(query) do
    products = ProductRepo.find_by_category_id(query.category_id)

    products =
      if query.include_subcategories do
        # サブカテゴリの商品も含める場合の実装
        # TODO: カテゴリツリーを辿ってサブカテゴリIDを収集
        products
      else
        products
      end

    {:ok, Enum.map(products, &format_product/1)}
  end
end
