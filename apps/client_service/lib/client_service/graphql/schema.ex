defmodule ClientService.GraphQL.Schema do
  @moduledoc """
  GraphQL スキーマ - API定義の中心
  """

  use Absinthe.Schema

  # 型定義のインポート
  import_types(ClientService.GraphQL.Types.Category)
  import_types(ClientService.GraphQL.Types.Product)
  import_types(ClientService.GraphQL.Types.Common)

  alias ClientService.GraphQL.Resolvers.{CategoryResolver, ProductResolver}

  # Query定義
  query do
    @desc "カテゴリ関連のクエリ"
    field :category, :category do
      arg(:id, non_null(:string))
      resolve(&CategoryResolver.get_category/3)
    end

    field :category_by_name, :category do
      arg(:name, non_null(:string))
      resolve(&CategoryResolver.get_category_by_name/3)
    end

    field :categories, list_of(:category) do
      resolve(&CategoryResolver.list_categories/3)
    end

    field :search_categories, list_of(:category) do
      arg(:search_term, non_null(:string))
      resolve(&CategoryResolver.search_categories/3)
    end

    field :categories_paginated, list_of(:category) do
      arg(:page, non_null(:integer))
      arg(:per_page, non_null(:integer))
      resolve(&CategoryResolver.list_categories_paginated/3)
    end

    field :category_statistics, :category_statistics do
      resolve(&CategoryResolver.get_statistics/3)
    end

    field :category_exists, :boolean do
      arg(:id, non_null(:string))
      resolve(&CategoryResolver.category_exists/3)
    end

    @desc "商品関連のクエリ"
    field :product, :product do
      arg(:id, non_null(:string))
      resolve(&ProductResolver.get_product/3)
    end

    field :product_by_name, :product do
      arg(:name, non_null(:string))
      resolve(&ProductResolver.get_product_by_name/3)
    end

    field :products, list_of(:product) do
      resolve(&ProductResolver.list_products/3)
    end

    field :search_products, list_of(:product) do
      arg(:search_term, non_null(:string))
      resolve(&ProductResolver.search_products/3)
    end

    field :products_paginated, list_of(:product) do
      arg(:page, non_null(:integer))
      arg(:per_page, non_null(:integer))
      resolve(&ProductResolver.list_products_paginated/3)
    end

    field :products_by_category, list_of(:product) do
      arg(:category_id, non_null(:string))
      resolve(&ProductResolver.get_products_by_category/3)
    end

    field :products_by_price_range, list_of(:product) do
      arg(:min_price, non_null(:float))
      arg(:max_price, non_null(:float))
      resolve(&ProductResolver.get_products_by_price_range/3)
    end

    field :product_statistics, :product_statistics do
      resolve(&ProductResolver.get_statistics/3)
    end

    field :product_exists, :boolean do
      arg(:id, non_null(:string))
      resolve(&ProductResolver.product_exists/3)
    end
  end

  # Mutation定義
  mutation do
    @desc "カテゴリ関連のミューテーション"
    field :create_category, :category do
      arg(:input, non_null(:category_create_input))
      resolve(&CategoryResolver.create_category/3)
    end

    field :update_category, :category do
      arg(:input, non_null(:category_update_input))
      resolve(&CategoryResolver.update_category/3)
    end

    field :delete_category, :boolean do
      arg(:id, non_null(:string))
      resolve(&CategoryResolver.delete_category/3)
    end

    @desc "商品関連のミューテーション"
    field :create_product, :product do
      arg(:input, non_null(:product_create_input))
      resolve(&ProductResolver.create_product/3)
    end

    field :update_product, :product do
      arg(:input, non_null(:product_update_input))
      resolve(&ProductResolver.update_product/3)
    end

    field :delete_product, :boolean do
      arg(:id, non_null(:string))
      resolve(&ProductResolver.delete_product/3)
    end
  end

  # Subscription定義（リアルタイム更新）
  subscription do
    @desc "カテゴリ関連のサブスクリプション"
    field :category_created, :category do
      config(fn _args, _context ->
        {:ok, topic: "*"}
      end)
    end

    field :category_updated, :category do
      arg(:id, :string)

      config(fn args, _context ->
        case args do
          %{id: id} -> {:ok, topic: id}
          _ -> {:ok, topic: "*"}
        end
      end)
    end

    field :category_deleted, :string do
      config(fn _args, _context ->
        {:ok, topic: "*"}
      end)
    end

    @desc "商品関連のサブスクリプション"
    field :product_created, :product do
      config(fn _args, _context ->
        {:ok, topic: "*"}
      end)
    end

    field :product_updated, :product do
      arg(:id, :string)

      config(fn args, _context ->
        case args do
          %{id: id} -> {:ok, topic: id}
          _ -> {:ok, topic: "*"}
        end
      end)
    end

    field :product_deleted, :string do
      config(fn _args, _context ->
        {:ok, topic: "*"}
      end)
    end
  end

  # エラーハンドリング
  def middleware(middleware, field, object) do
    middleware
    |> apply_middleware(:errors, [field, object])
    |> apply_middleware(:auth, [field, object])
  end

  # カスタムミドルウェア
  defp apply_middleware(middleware, :errors, [_field, %{identifier: :mutation}]) do
    middleware ++ [ClientService.GraphQL.Middleware.ErrorHandler]
  end

  defp apply_middleware(middleware, :errors, _) do
    middleware ++ [ClientService.GraphQL.Middleware.ErrorHandler]
  end

  defp apply_middleware(middleware, :auth, [_field, %{identifier: :mutation}]) do
    [ClientService.GraphQL.Middleware.AuthHandler] ++ middleware
  end

  defp apply_middleware(middleware, :auth, _) do
    middleware
  end

  defp apply_middleware(middleware, _, _), do: middleware
end
