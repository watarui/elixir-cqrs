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

  # handleメソッドの実装（test_support_queriesのクエリを処理）
  def handle(%{__struct__: module} = query) do
    # test_support_queriesのクエリモジュールに対応
    case module do
      QueryService.Application.Queries.GetCategoryQuery ->
        handle_get_category_query(query)

      QueryService.Application.Queries.ListCategoriesQuery ->
        handle_list_categories_query(query)

      QueryService.Application.Queries.GetCategoryTreeQuery ->
        handle_get_category_tree_query(query)

      QueryService.Application.Queries.GetCategoryPathQuery ->
        handle_get_category_path_query(query)

      _ ->
        # 既存のクエリはhandle_queryに委譲
        handle_query(query)
    end
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

  # 新しいクエリモジュールのハンドラー実装
  defp handle_get_category_query(query) do
    case CategoryRepo.find_by_id(query.id) do
      {:ok, category} ->
        result = format_category(category)

        # include_childrenオプションの処理
        result =
          if query.include_children do
            children = get_child_categories(category.id)
            Map.put(result, :children, Enum.map(children, &format_category/1))
          else
            result
          end

        # include_parentオプションの処理
        result =
          if query.include_parent && category.parent_id do
            case CategoryRepo.find_by_id(category.parent_id) do
              {:ok, parent} -> Map.put(result, :parent, format_category(parent))
              _ -> result
            end
          else
            result
          end

        # include_product_countオプションの処理
        result =
          if query.include_product_count do
            count = ProductRepo.count_by_category(category.id)
            Map.put(result, :product_count, count)
          else
            result
          end

        {:ok, result}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp handle_list_categories_query(query) do
    categories = CategoryRepo.list()

    # レベルやparent_idでフィルタリング
    categories =
      cond do
        query.level != nil ->
          Enum.filter(categories, &(&1.level == query.level))

        query.parent_id != nil ->
          Enum.filter(categories, &(&1.parent_id == query.parent_id))

        true ->
          categories
      end

    # active_onlyフィルター
    categories =
      if query.active_only do
        Enum.filter(categories, & &1.is_active)
      else
        categories
      end

    # include_childrenオプション
    categories =
      if query.include_children do
        Enum.map(categories, fn cat ->
          children = get_child_categories(cat.id, query.max_depth || 1)
          Map.put(format_category(cat), :children, Enum.map(children, &format_category/1))
        end)
      else
        Enum.map(categories, &format_category/1)
      end

    {:ok, categories}
  end

  defp handle_get_category_tree_query(query) do
    root_categories =
      if query.root_id do
        case CategoryRepo.find_by_id(query.root_id) do
          {:ok, root} -> [root]
          _ -> []
        end
      else
        CategoryRepo.find_root_categories()
      end

    tree =
      build_category_tree(root_categories, query.max_depth || 999, query.active_only || false)

    tree =
      if query.include_metadata do
        add_tree_metadata(tree)
      else
        tree
      end

    {:ok, tree}
  end

  defp handle_get_category_path_query(query) do
    case CategoryRepo.find_by_id(query.id) do
      {:ok, category} ->
        path = build_category_path(category)

        path =
          if query.format == "breadcrumb" do
            %{
              path: path,
              breadcrumb: Enum.map(path, &%{id: &1.id, name: &1.name})
            }
          else
            path
          end

        {:ok, path}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  # ヘルパー関数
  defp get_child_categories(parent_id, max_depth \\ 1, current_depth \\ 0) do
    if current_depth >= max_depth do
      []
    else
      children = CategoryRepo.find_by_parent_id(parent_id)

      Enum.flat_map(children, fn child ->
        grandchildren = get_child_categories(child.id, max_depth, current_depth + 1)
        [child | grandchildren]
      end)
    end
  end

  defp build_category_tree(categories, max_depth, active_only, current_depth \\ 0) do
    Enum.map(categories, fn category ->
      children =
        if current_depth < max_depth do
          child_categories = CategoryRepo.find_by_parent_id(category.id)

          child_categories =
            if active_only do
              Enum.filter(child_categories, & &1.is_active)
            else
              child_categories
            end

          build_category_tree(child_categories, max_depth, active_only, current_depth + 1)
        else
          []
        end

      format_category(category)
      |> Map.put(:children, children)
    end)
  end

  defp build_category_path(category, path \\ []) do
    path = [format_category(category) | path]

    if category.parent_id do
      case CategoryRepo.find_by_id(category.parent_id) do
        {:ok, parent} -> build_category_path(parent, path)
        _ -> path
      end
    else
      path
    end
  end

  defp add_tree_metadata(tree) do
    Enum.map(tree, fn node ->
      node
      |> Map.put(:level, calculate_level(node))
      |> Map.put(:has_children, length(Map.get(node, :children, [])) > 0)
      |> Map.update(:children, [], &add_tree_metadata/1)
    end)
  end

  defp calculate_level(%{parent_id: nil}), do: 0

  defp calculate_level(%{parent_id: parent_id}) do
    case CategoryRepo.find_by_id(parent_id) do
      {:ok, parent} -> calculate_level(format_category(parent)) + 1
      _ -> 0
    end
  end
end
