defmodule ClientService.GraphQL.Types.Order do
  @moduledoc """
  注文関連の GraphQL 型定義
  """

  use Absinthe.Schema.Notation

  @desc "注文ステータス"
  enum :order_status do
    value(:pending, description: "保留中")
    value(:processing, description: "処理中")
    value(:confirmed, description: "確定済み")
    value(:cancelled, description: "キャンセル済み")
    value(:failed, description: "失敗")
  end

  @desc "注文"
  object :order do
    field(:id, non_null(:id))
    field(:user_id, non_null(:string))
    field(:status, non_null(:order_status))
    field(:total_amount, non_null(:decimal))
    field(:items, non_null(list_of(:order_item)))
    field(:created_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
  end

  @desc "注文アイテム"
  object :order_item do
    field(:product_id, non_null(:id))
    field(:product_name, non_null(:string))
    field(:quantity, non_null(:integer))
    field(:unit_price, non_null(:decimal))
    field(:subtotal, non_null(:decimal))
  end

  @desc "注文作成入力"
  input_object :create_order_input do
    field(:user_id, non_null(:string))
    field(:items, non_null(list_of(:order_item_input)))
  end

  @desc "注文アイテム入力"
  input_object :order_item_input do
    field(:product_id, non_null(:id))
    field(:product_name, non_null(:string))
    field(:quantity, non_null(:integer))
    field(:unit_price, non_null(:decimal))
  end

  @desc "注文結果"
  object :order_result do
    field(:success, non_null(:boolean))
    field(:order, :order)
    field(:message, :string)
  end
end