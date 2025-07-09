defmodule ClientService.GraphQL.Types.Product do
  @moduledoc """
  商品関連の GraphQL 型定義
  """

  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  @desc "商品"
  object :product do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
    field(:description, :string)
    field(:price, non_null(:decimal))
    field(:currency, non_null(:string))
    field(:category_id, non_null(:id))
    field(:stock_quantity, :integer)
    field(:active, :boolean)

    field :category, :category do
      resolve(dataloader(:query_service))
    end

    field(:created_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
  end

  @desc "商品作成入力"
  input_object :create_product_input do
    field(:name, non_null(:string))
    field(:description, :string)
    field(:price, non_null(:decimal))
    field(:category_id, non_null(:id))
    field(:stock_quantity, :integer)
  end

  @desc "商品更新入力"
  input_object :update_product_input do
    field(:name, :string)
    field(:description, :string)
    field(:price, :decimal)
    field(:category_id, :id)
    field(:stock_quantity, :integer)
  end
end
