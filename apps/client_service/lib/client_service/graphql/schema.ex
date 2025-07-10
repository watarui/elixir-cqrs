defmodule ClientService.GraphQL.Schema do
  @moduledoc """
  GraphQL スキーマ定義
  """

  use Absinthe.Schema

  import_types(Absinthe.Type.Custom)
  import_types(ClientService.GraphQL.Types.Common)
  import_types(ClientService.GraphQL.Types.Category)
  import_types(ClientService.GraphQL.Types.Product)

  alias ClientService.GraphQL.{Dataloader, Resolvers}

  # PubSub版のリゾルバーを使用
  alias ClientService.GraphQL.Resolvers.CategoryResolverPubsub, as: CategoryResolver
  alias ClientService.GraphQL.Resolvers.ProductResolverPubsub, as: ProductResolver

  query do
    @desc "カテゴリを取得"
    field :category, :category do
      arg(:id, non_null(:id))
      resolve(&CategoryResolver.get_category/3)
    end

    @desc "カテゴリ一覧を取得"
    field :categories, list_of(:category) do
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      arg(:sort_by, :string, default_value: "name")
      arg(:sort_order, :sort_order, default_value: :asc)
      resolve(&CategoryResolver.list_categories/3)
    end

    @desc "カテゴリを検索"
    field :search_categories, list_of(:category) do
      arg(:search_term, non_null(:string))
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      resolve(&CategoryResolver.search_categories/3)
    end

    @desc "商品を取得"
    field :product, :product do
      arg(:id, non_null(:id))
      resolve(&ProductResolver.get_product/3)
    end

    @desc "商品一覧を取得"
    field :products, list_of(:product) do
      arg(:category_id, :id)
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      arg(:sort_by, :string, default_value: "name")
      arg(:sort_order, :sort_order, default_value: :asc)
      arg(:min_price, :decimal)
      arg(:max_price, :decimal)
      resolve(&ProductResolver.list_products/3)
    end

    @desc "商品を検索"
    field :search_products, list_of(:product) do
      arg(:search_term, non_null(:string))
      arg(:category_id, :id)
      arg(:limit, :integer, default_value: 20)
      arg(:offset, :integer, default_value: 0)
      resolve(&ProductResolver.search_products/3)
    end
  end

  mutation do
    @desc "カテゴリを作成"
    field :create_category, :category do
      arg(:input, non_null(:create_category_input))
      resolve(&CategoryResolver.create_category/3)
    end

    @desc "カテゴリを更新"
    field :update_category, :category do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_category_input))
      resolve(&CategoryResolver.update_category/3)
    end

    @desc "カテゴリを削除"
    field :delete_category, :delete_result do
      arg(:id, non_null(:id))
      resolve(&CategoryResolver.delete_category/3)
    end

    @desc "商品を作成"
    field :create_product, :product do
      arg(:input, non_null(:create_product_input))
      resolve(&ProductResolver.create_product/3)
    end

    @desc "商品を更新"
    field :update_product, :product do
      arg(:id, non_null(:id))
      arg(:input, non_null(:update_product_input))
      resolve(&ProductResolver.update_product/3)
    end

    @desc "商品価格を変更"
    field :change_product_price, :product do
      arg(:id, non_null(:id))
      arg(:new_price, non_null(:decimal))
      resolve(&ProductResolver.change_product_price/3)
    end

    @desc "商品を削除"
    field :delete_product, :delete_result do
      arg(:id, non_null(:id))
      resolve(&ProductResolver.delete_product/3)
    end
  end

  # Subscription の定義（将来の拡張用）
  # subscription do
  #   field :category_updated, :category do
  #     config fn _args, _info ->
  #       {:ok, topic: "categories:*"}
  #     end
  #   end
  # end

  # Dataloader の設定
  def context(ctx) do
    loader = Dataloader.new()
    Map.put(ctx, :loader, loader)
  end

  def plugins do
    # Dataloader の依存関係の問題を回避するため一時的に無効化
    # [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
    Absinthe.Plugin.defaults()
  end
end
