defmodule CommandService.Domain.Commands.Compensations do
  @moduledoc """
  Saga補償用のコマンド定義
  """

  defmodule CancelInventoryReservation do
    @moduledoc """
    在庫予約キャンセルコマンド
    """
    defstruct [:order_id, :product_id, :quantity]
  end

  defmodule RefundPayment do
    @moduledoc """
    支払い返金コマンド
    """
    defstruct [:order_id, :payment_id, :amount]
  end

  defmodule CancelShipping do
    @moduledoc """
    配送キャンセルコマンド
    """
    defstruct [:order_id, :shipping_id]
  end
end