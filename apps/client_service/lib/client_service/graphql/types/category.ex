defmodule ClientService.GraphQL.Types.Category do
  @moduledoc """
  カテゴリ用GraphQL型定義
  """

  use Absinthe.Schema.Notation

  # カテゴリ型定義
  object :category do
    field(:id, non_null(:string), description: "カテゴリID")
    field(:name, non_null(:string), description: "カテゴリ名")
    field(:created_at, :datetime, description: "作成日時")
    field(:updated_at, :datetime, description: "更新日時")

    # 関連商品を遅延読み込み
    field :products, list_of(:product) do
      description("このカテゴリに属する商品一覧")
      resolve(&ClientService.GraphQL.Resolvers.CategoryResolver.get_products/3)
    end
  end

  # カテゴリ統計情報
  object :category_statistics do
    field(:total_count, non_null(:integer), description: "全カテゴリ数")
    field(:has_categories, non_null(:boolean), description: "カテゴリが存在するか")
    field(:categories_with_timestamps, list_of(:category), description: "タイムスタンプ付きカテゴリ一覧")
  end

  # 入力型定義
  input_object :category_create_input do
    field(:name, non_null(:string), description: "カテゴリ名")
  end

  input_object :category_update_input do
    field(:id, non_null(:string), description: "カテゴリID")
    field(:name, non_null(:string), description: "新しいカテゴリ名")
  end
end
