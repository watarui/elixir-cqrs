defmodule ClientService.GraphQL.Types.Product do
  @moduledoc """
  商品用GraphQL型定義
  """

  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers

  # 商品型定義
  object :product do
    field(:id, non_null(:string), description: "商品ID")
    field(:name, non_null(:string), description: "商品名")
    field(:price, non_null(:float), description: "価格")
    field(:category_id, non_null(:string), description: "カテゴリID")
    field(:created_at, :datetime, description: "作成日時")
    field(:updated_at, :datetime, description: "更新日時")

    # 関連カテゴリを遅延読み込み
    field :category, :category do
      description("この商品が属するカテゴリ")
      resolve(&ClientService.GraphQL.Resolvers.ProductResolver.get_category/3)
    end
  end

  # 商品統計情報
  object :product_statistics do
    field(:total_count, non_null(:integer), description: "全商品数")
    field(:has_products, :boolean, description: "商品が存在するかどうか")
    field(:average_price, :float, description: "平均価格")
    field(:total_value, :float, description: "総価値")
    field(:products_with_timestamps, list_of(:product), description: "タイムスタンプ付き商品")
  end

  # 入力型定義
  input_object :product_create_input do
    field(:name, non_null(:string), description: "商品名")
    field(:price, non_null(:float), description: "価格")
    field(:category_id, non_null(:string), description: "カテゴリID")
  end

  input_object :product_update_input do
    field(:id, non_null(:string), description: "商品ID")
    field(:name, :string, description: "新しい商品名")
    field(:price, :float, description: "新しい価格")
    field(:category_id, :string, description: "新しいカテゴリID")
  end
end
