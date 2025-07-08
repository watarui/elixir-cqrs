defmodule CommandService.Application.Handlers.SagaCommandHandler do
  @moduledoc """
  SAGAから送信されるコマンドを処理するハンドラー
  """

  require Logger
  alias Shared.Infrastructure.EventBus

  def handle_command(%{type: "reserve_inventory", payload: payload} = command) do
    metadata = Map.get(command, :metadata, %{})
    handle_reserve_inventory(payload, metadata)
  end

  def handle_command(%{type: "process_payment", payload: payload} = command) do
    metadata = Map.get(command, :metadata, %{})
    handle_process_payment(payload, metadata)
  end

  def handle_command(%{type: "arrange_shipping", payload: payload} = command) do
    metadata = Map.get(command, :metadata, %{})
    handle_arrange_shipping(payload, metadata)
  end

  def handle_command(%{type: "confirm_order", payload: payload} = command) do
    metadata = Map.get(command, :metadata, %{})
    handle_confirm_order(payload, metadata)
  end

  def handle_command(%{type: "cancel_inventory", payload: payload} = command) do
    metadata = Map.get(command, :metadata, %{})
    handle_cancel_inventory(payload, metadata)
  end

  def handle_command(%{type: "refund_payment", payload: payload} = command) do
    metadata = Map.get(command, :metadata, %{})
    handle_refund_payment(payload, metadata)
  end

  def handle_command(%{type: "cancel_shipping", payload: payload} = command) do
    metadata = Map.get(command, :metadata, %{})
    handle_cancel_shipping(payload, metadata)
  end

  def handle_command(command) do
    Logger.error("Unknown command: #{inspect(command)}")
    {:error, :unknown_command}
  end

  # 在庫予約の処理
  defp handle_reserve_inventory(payload, metadata) do
    Logger.info("Reserving inventory for order #{payload.order_id}")

    # シミュレーション：処理時間
    Process.sleep(100)

    # 成功イベントを発行
    event = %{
      event_id: UUID.uuid4(),
      event_type: "inventory_reserved",
      aggregate_id: payload.order_id,
      occurred_at: DateTime.utc_now(),
      payload: %{
        order_id: payload.order_id,
        product_id: payload.product_id,
        quantity: payload.quantity,
        reserved_at: DateTime.utc_now()
      },
      metadata: Map.put(metadata, :source, "SagaCommandHandler")
    }

    EventBus.publish(event)

    # SAGAコーディネーターにも直接通知
    if _saga_id = Map.get(metadata, :saga_id) do
      GenServer.cast(Shared.Infrastructure.Saga.SagaCoordinator, {:process_event, event})
    end

    {:ok, %{reserved: true, product_id: payload.product_id}}
  end

  # 支払い処理
  defp handle_process_payment(payload, metadata) do
    Logger.info("Processing payment for order #{payload.order_id}")

    Process.sleep(150)

    payment_id = "payment-#{System.unique_integer([:positive])}"

    # 成功イベントを発行
    event = %{
      event_id: UUID.uuid4(),
      event_type: "payment_processed",
      aggregate_id: payload.order_id,
      occurred_at: DateTime.utc_now(),
      payload: %{
        order_id: payload.order_id,
        payment_id: payment_id,
        amount: payload.amount,
        customer_id: payload.customer_id,
        processed_at: DateTime.utc_now()
      },
      metadata: Map.put(metadata, :source, "SagaCommandHandler")
    }

    EventBus.publish(event)

    if _saga_id = Map.get(metadata, :saga_id) do
      GenServer.cast(Shared.Infrastructure.Saga.SagaCoordinator, {:process_event, event})
    end

    {:ok, %{payment_id: payment_id, processed: true}}
  end

  # 配送手配
  defp handle_arrange_shipping(payload, metadata) do
    Logger.info("Arranging shipping for order #{payload.order_id}")

    Process.sleep(100)

    shipping_id = "ship-#{System.unique_integer([:positive])}"

    # 成功イベントを発行
    event = %{
      event_id: UUID.uuid4(),
      event_type: "shipping_arranged",
      aggregate_id: payload.order_id,
      occurred_at: DateTime.utc_now(),
      payload: %{
        order_id: payload.order_id,
        shipping_id: shipping_id,
        shipping_address: payload.shipping_address,
        arranged_at: DateTime.utc_now()
      },
      metadata: Map.put(metadata, :source, "SagaCommandHandler")
    }

    EventBus.publish(event)

    if _saga_id = Map.get(metadata, :saga_id) do
      GenServer.cast(Shared.Infrastructure.Saga.SagaCoordinator, {:process_event, event})
    end

    {:ok, %{shipping_id: shipping_id, arranged: true}}
  end

  # 注文確定
  defp handle_confirm_order(payload, metadata) do
    Logger.info("Confirming order #{payload.order_id}")

    Process.sleep(50)

    # 成功イベントを発行
    event = %{
      event_id: UUID.uuid4(),
      event_type: "order_confirmed",
      aggregate_id: payload.order_id,
      occurred_at: DateTime.utc_now(),
      payload: %{
        order_id: payload.order_id,
        confirmed_at: DateTime.utc_now(),
        status: "confirmed"
      },
      metadata: Map.put(metadata, :source, "SagaCommandHandler")
    }

    EventBus.publish(event)

    if _saga_id = Map.get(metadata, :saga_id) do
      GenServer.cast(Shared.Infrastructure.Saga.SagaCoordinator, {:process_event, event})
    end

    {:ok, %{confirmed: true, status: "confirmed"}}
  end

  # 在庫予約キャンセル（補償処理）
  defp handle_cancel_inventory(payload, _metadata) do
    Logger.info("Cancelling inventory reservation for order #{payload.order_id}")

    Process.sleep(100)

    {:ok, %{cancelled: true, product_id: payload.product_id}}
  end

  # 支払い返金（補償処理）
  defp handle_refund_payment(payload, _metadata) do
    Logger.info("Refunding payment for order #{payload.order_id}")

    Process.sleep(150)

    {:ok, %{refunded: true, payment_id: payload.payment_id}}
  end

  # 配送キャンセル（補償処理）
  defp handle_cancel_shipping(payload, _metadata) do
    Logger.info("Cancelling shipping for order #{payload.order_id}")

    Process.sleep(100)

    {:ok, %{cancelled: true, shipping_id: payload.shipping_id}}
  end
end
