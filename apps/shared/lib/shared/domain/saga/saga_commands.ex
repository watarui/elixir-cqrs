defmodule Shared.Domain.Saga.Commands do
  @moduledoc """
  Saga用のコマンド定義
  """

  defmodule ReserveInventory do
    @moduledoc """
    在庫予約コマンド
    """
    defstruct [:order_id, :product_id, :quantity]
  end

  defmodule ProcessPayment do
    @moduledoc """
    支払い処理コマンド
    """
    defstruct [:order_id, :customer_id, :amount]
  end

  defmodule ArrangeShipping do
    @moduledoc """
    配送手配コマンド
    """
    defstruct [:order_id, :shipping_address]
  end

  defmodule ConfirmOrder do
    @moduledoc """
    注文確定コマンド
    """
    defstruct [:order_id]
  end

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
