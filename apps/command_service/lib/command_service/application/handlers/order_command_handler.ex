defmodule CommandService.Application.Handlers.OrderCommandHandler do
  @moduledoc """
  注文関連のコマンドハンドラー
  サガから呼ばれるコマンドを処理します
  """

  use CommandService.Application.Handlers.BaseCommandHandler

  alias CommandService.Domain.Commands.{
    ArrangeShipping,
    CancelOrder,
    CancelShipping,
    ConfirmOrder,
    ProcessPayment,
    RefundPayment,
    ReleaseInventory,
    ReserveInventory
  }

  alias Shared.Infrastructure.EventStore.EventStore
  require Logger

  @impl true
  def command_types do
    [
      ReserveInventory,
      ReleaseInventory,
      ProcessPayment,
      RefundPayment,
      ArrangeShipping,
      CancelShipping,
      ConfirmOrder,
      CancelOrder
    ]
  end

  @impl true
  def handle_command(%ReserveInventory{} = command) do
    Logger.info("Reserving inventory for order: #{command.order_id}")

    # シミュレーション：実際の実装では在庫管理システムと連携
    # ここでは成功を仮定
    event = %{
      event_type: "InventoryReserved",
      order_id: command.order_id,
      product_id: command.product_id,
      quantity: command.quantity,
      reserved_at: DateTime.utc_now()
    }

    publish_event(event)
    {:ok, %{reserved: true, order_id: command.order_id}}
  end

  @impl true
  def handle_command(%ReleaseInventory{} = command) do
    Logger.info("Releasing inventory for order: #{command.order_id}")

    event = %{
      event_type: "InventoryReleased",
      order_id: command.order_id,
      product_id: command.product_id,
      quantity: command.quantity,
      released_at: DateTime.utc_now()
    }

    publish_event(event)
    {:ok, %{released: true, order_id: command.order_id}}
  end

  @impl true
  def handle_command(%ProcessPayment{} = command) do
    Logger.info("Processing payment for order: #{command.order_id}")

    # シミュレーション：実際の実装では決済システムと連携
    # ここでは成功を仮定
    event = %{
      event_type: "PaymentProcessed",
      order_id: command.order_id,
      customer_id: command.customer_id,
      amount: command.amount,
      payment_id: "payment-#{:rand.uniform(999_999)}",
      processed_at: DateTime.utc_now()
    }

    publish_event(event)
    {:ok, %{payment_processed: true, order_id: command.order_id}}
  end

  @impl true
  def handle_command(%RefundPayment{} = command) do
    Logger.info("Refunding payment for order: #{command.order_id}")

    event = %{
      event_type: "PaymentRefunded",
      order_id: command.order_id,
      amount: command.amount,
      refund_id: "refund-#{:rand.uniform(999_999)}",
      refunded_at: DateTime.utc_now()
    }

    publish_event(event)
    {:ok, %{refunded: true, order_id: command.order_id}}
  end

  @impl true
  def handle_command(%ArrangeShipping{} = command) do
    Logger.info("Arranging shipping for order: #{command.order_id}")

    # シミュレーション：実際の実装では配送システムと連携
    event = %{
      event_type: "ShippingArranged",
      order_id: command.order_id,
      shipping_address: command.shipping_address,
      tracking_number: "TRACK-#{:rand.uniform(999_999_999)}",
      arranged_at: DateTime.utc_now()
    }

    publish_event(event)
    {:ok, %{shipping_arranged: true, order_id: command.order_id}}
  end

  @impl true
  def handle_command(%CancelShipping{} = command) do
    Logger.info("Cancelling shipping for order: #{command.order_id}")

    event = %{
      event_type: "ShippingCancelled",
      order_id: command.order_id,
      cancelled_at: DateTime.utc_now()
    }

    publish_event(event)
    {:ok, %{shipping_cancelled: true, order_id: command.order_id}}
  end

  @impl true
  def handle_command(%ConfirmOrder{} = command) do
    Logger.info("Confirming order: #{command.order_id}")

    event = %{
      event_type: "OrderConfirmed",
      order_id: command.order_id,
      confirmed_at: DateTime.utc_now()
    }

    publish_event(event)
    {:ok, %{order_confirmed: true, order_id: command.order_id}}
  end

  @impl true
  def handle_command(%CancelOrder{} = command) do
    Logger.info("Cancelling order: #{command.order_id}")

    event = %{
      event_type: "OrderCancelled",
      order_id: command.order_id,
      cancelled_at: DateTime.utc_now()
    }

    publish_event(event)
    {:ok, %{order_cancelled: true, order_id: command.order_id}}
  end

  # Private functions

  defp publish_event(event) do
    stream_name = "order-#{event.order_id}"

    Shared.Infrastructure.EventStore.append_to_stream(
      stream_name,
      [event],
      :any
    )
  end
end
