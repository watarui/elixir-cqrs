defmodule ClientService.GraphQL.Types.Order do
  @moduledoc """
  注文関連のGraphQL型定義
  """

  use Absinthe.Schema.Notation

  # 注文型
  object :order do
    field(:id, non_null(:string))
    field(:user_id, non_null(:string))
    field(:status, non_null(:order_status))
    field(:total_amount, non_null(:float))
    field(:items, non_null(list_of(:order_item)))
    field(:created_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
    field(:saga_state, :saga_state)
  end

  # 注文アイテム型
  object :order_item do
    field(:product_id, non_null(:string))
    field(:product_name, non_null(:string))
    field(:quantity, non_null(:integer))
    field(:price, non_null(:float))
    field(:subtotal, non_null(:float))
  end

  # 注文ステータス列挙型
  enum :order_status do
    value(:pending, description: "処理待ち")
    value(:processing, description: "処理中")
    value(:confirmed, description: "確定")
    value(:shipped, description: "発送済み")
    value(:delivered, description: "配達済み")
    value(:cancelled, description: "キャンセル")
    value(:failed, description: "失敗")
  end

  # サガ状態型
  object :saga_state do
    field(:state, non_null(:string))
    field(:status, non_null(:saga_status))
    field(:started_at, :datetime)
    field(:completed_at, :datetime)
    field(:current_step, :string)
    field(:failure_reason, :string)
  end

  # サガステータス列挙型
  enum :saga_status do
    value(:started, description: "開始")
    value(:processing, description: "処理中")
    value(:compensating, description: "補償処理中")
    value(:completed, description: "完了")
    value(:failed, description: "失敗")
    value(:compensated, description: "補償完了")
  end

  # 注文作成入力型
  input_object :order_create_input do
    field(:user_id, non_null(:string))
    field(:items, non_null(list_of(:order_item_input)))
  end

  # 注文アイテム入力型
  input_object :order_item_input do
    field(:product_id, non_null(:string))
    field(:quantity, non_null(:integer))
  end

  # 注文キャンセル入力型
  input_object :order_cancel_input do
    field(:order_id, non_null(:string))
    field(:reason, :string)
  end

  # Order SAGA入力型
  input_object :order_saga_input do
    field(:order_id, non_null(:string))
    field(:user_id, non_null(:string))
    field(:items, non_null(list_of(:order_item_input)))
    field(:total_amount, non_null(:float))
    field(:shipping_address, :shipping_address_input)
  end

  # 配送先住所入力型
  input_object :shipping_address_input do
    field(:street, non_null(:string))
    field(:city, non_null(:string))
    field(:postal_code, non_null(:string))
  end

  # SAGA開始結果型
  object :saga_start_result do
    field(:saga_id, non_null(:string))
    field(:success, non_null(:boolean))
    field(:message, :string)
    field(:started_at, non_null(:datetime))
  end
end
