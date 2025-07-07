defmodule CommandService.Domain.Commands.ReserveInventory do
  @moduledoc """
  在庫予約コマンド
  """
  defstruct [:order_id, :product_id, :quantity]
end

defmodule CommandService.Domain.Commands.ReleaseInventory do
  @moduledoc """
  在庫開放コマンド
  """
  defstruct [:order_id, :product_id, :quantity]
end

defmodule CommandService.Domain.Commands.ProcessPayment do
  @moduledoc """
  支払い処理コマンド
  """
  defstruct [:order_id, :customer_id, :amount]
end

defmodule CommandService.Domain.Commands.RefundPayment do
  @moduledoc """
  払い戻しコマンド
  """
  defstruct [:order_id, :customer_id, :amount]
end

defmodule CommandService.Domain.Commands.ArrangeShipping do
  @moduledoc """
  配送手配コマンド
  """
  defstruct [:order_id, :shipping_address]
end

defmodule CommandService.Domain.Commands.CancelShipping do
  @moduledoc """
  配送キャンセルコマンド
  """
  defstruct [:order_id]
end

defmodule CommandService.Domain.Commands.ConfirmOrder do
  @moduledoc """
  注文確定コマンド
  """
  defstruct [:order_id]
end

defmodule CommandService.Domain.Commands.CancelOrder do
  @moduledoc """
  注文キャンセルコマンド
  """
  defstruct [:order_id]
end
