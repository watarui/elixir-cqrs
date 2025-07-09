defmodule CommandService.Domain.Sagas.OrderSaga do
  @moduledoc """
  注文処理のサガ実装

  注文の作成から確定までの分散トランザクションを管理します
  """

  use Shared.Domain.Saga.SagaBase

  @impl true
  def new(saga_id, initial_data) do
    %{
      saga_id: saga_id,
      order_id: initial_data[:order_id],
      user_id: initial_data[:user_id],
      items: initial_data[:items] || [],
      total_amount: initial_data[:total_amount],
      state: :started,
      current_step: :reserve_inventory,
      # ステップの完了状態
      inventory_reserved: false,
      payment_processed: false,
      shipping_arranged: false,
      order_confirmed: false,
      # 補償に必要な情報
      reservation_ids: [],
      payment_id: nil,
      shipping_id: nil,
      # メタデータ
      started_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      completed_steps: [],
      processed_events: []
    }
  end

  @impl true
  def handle_event(event, saga) do
    saga = record_processed_event(saga, event)

    case {saga.current_step, event.__struct__} do
      # 在庫予約完了
      {:reserve_inventory, Shared.Domain.Events.OrderEvents.OrderItemReserved} ->
        saga = %{
          saga
          | inventory_reserved: true,
            reservation_ids: [event.product_id | saga.reservation_ids]
        }

        # すべての商品の在庫が予約されたかチェック
        if all_items_reserved?(saga) do
          saga =
            saga
            |> complete_step(:reserve_inventory)
            |> Map.put(:current_step, :process_payment)

          commands = [create_payment_command(saga)]
          {:ok, commands}
        else
          # まだ予約が必要な商品がある
          {:ok, []}
        end

      # 支払い処理完了
      {:process_payment, Shared.Domain.Events.OrderEvents.OrderPaymentProcessed} ->
        saga =
          saga
          |> Map.put(:payment_processed, true)
          |> Map.put(:payment_id, event.payment_id)
          |> complete_step(:process_payment)
          |> Map.put(:current_step, :arrange_shipping)

        commands = [create_shipping_command(saga)]
        {:ok, commands}

      # 配送手配完了
      {:arrange_shipping, _shipping_event} ->
        saga =
          saga
          |> Map.put(:shipping_arranged, true)
          |> Map.put(:shipping_id, event.shipping_id)
          |> complete_step(:arrange_shipping)
          |> Map.put(:current_step, :confirm_order)

        commands = [create_order_confirmation_command(saga)]
        {:ok, commands}

      # 注文確定
      {:confirm_order, Shared.Domain.Events.OrderEvents.OrderConfirmed} ->
        _updated_saga =
          saga
          |> Map.put(:order_confirmed, true)
          |> complete_step(:confirm_order)
          |> complete_saga()

        {:ok, []}

      # エラーイベント
      {_, _error_event} ->
        failed_saga = record_failure(saga, saga.current_step, "Step failed")
        compensation_commands = get_compensation_commands(failed_saga)
        {:ok, compensation_commands}
    end
  end

  @impl true
  def get_compensation_commands(saga) do
    commands = []

    # 完了したステップを逆順に補償
    commands =
      if saga.shipping_arranged do
        [create_cancel_shipping_command(saga) | commands]
      else
        commands
      end

    commands =
      if saga.payment_processed do
        [create_refund_payment_command(saga) | commands]
      else
        commands
      end

    commands =
      if saga.inventory_reserved do
        release_commands =
          Enum.map(saga.reservation_ids, fn product_id ->
            create_release_inventory_command(saga, product_id)
          end)

        release_commands ++ commands
      else
        commands
      end

    # 最後に注文をキャンセル
    [create_cancel_order_command(saga) | commands]
  end

  @impl true
  def completed?(saga) do
    saga.state == :completed && saga.order_confirmed
  end

  @impl true
  def failed?(saga) do
    saga.state in [:failed, :compensated]
  end

  # Private functions

  defp all_items_reserved?(saga) do
    item_count = length(saga.items)
    reserved_count = length(saga.reservation_ids)
    item_count == reserved_count
  end

  defp create_payment_command(saga) do
    %{
      command_type: "process_payment",
      order_id: saga.order_id,
      user_id: saga.user_id,
      amount: saga.total_amount,
      saga_id: saga.saga_id
    }
  end

  defp create_shipping_command(saga) do
    %{
      command_type: "arrange_shipping",
      order_id: saga.order_id,
      user_id: saga.user_id,
      items: saga.items,
      saga_id: saga.saga_id
    }
  end

  defp create_order_confirmation_command(saga) do
    %{
      command_type: "confirm_order",
      order_id: saga.order_id,
      saga_id: saga.saga_id
    }
  end

  defp create_cancel_shipping_command(saga) do
    %{
      command_type: "cancel_shipping",
      order_id: saga.order_id,
      shipping_id: saga.shipping_id,
      saga_id: saga.saga_id
    }
  end

  defp create_refund_payment_command(saga) do
    %{
      command_type: "refund_payment",
      order_id: saga.order_id,
      payment_id: saga.payment_id,
      amount: saga.total_amount,
      saga_id: saga.saga_id
    }
  end

  defp create_release_inventory_command(saga, product_id) do
    %{
      command_type: "release_inventory",
      order_id: saga.order_id,
      product_id: product_id,
      saga_id: saga.saga_id
    }
  end

  defp create_cancel_order_command(saga) do
    %{
      command_type: "cancel_order",
      order_id: saga.order_id,
      reason: saga[:failure_reason] || "Saga failed",
      saga_id: saga.saga_id
    }
  end
end
