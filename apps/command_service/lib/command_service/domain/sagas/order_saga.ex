defmodule CommandService.Domain.Sagas.OrderSaga do
  @moduledoc """
  注文処理サガの実装例

  以下のステップを実行します：
  1. 在庫の確認と予約
  2. 支払い処理
  3. 配送手配
  4. 注文確定

  いずれかのステップが失敗した場合、補償トランザクションを実行します。
  """

  use Shared.Domain.Saga.SagaBase

  alias CommandService.Application.Commands.OrderCommands.{
    ArrangeShippingCommand,
    CancelOrderCommand,
    CancelShippingCommand,
    ConfirmOrderCommand,
    ProcessPaymentCommand,
    RefundPaymentCommand,
    ReleaseInventoryCommand,
    ReserveInventoryCommand
  }

  # Public API
  def new(saga_id, initial_data) do
    %{
      saga_id: saga_id,
      order_id: initial_data[:order_id],
      user_id: initial_data[:user_id] || initial_data[:customer_id],
      customer_id: initial_data[:customer_id] || initial_data[:user_id],
      items: initial_data[:items] || [],
      total_amount: initial_data[:total_amount],
      shipping_address: initial_data[:shipping_address],
      state: :started,
      current_step: :reserve_inventory,
      processed_events: [],
      # サガ固有の状態
      inventory_reserved: false,
      payment_processed: false,
      shipping_arranged: false,
      order_confirmed: false
    }
  end

  def next_step(saga) do
    cond do
      saga.state == :completed ->
        {:ok, []}

      saga.state == :failed ->
        {:ok, []}

      true ->
        case saga.current_step do
          :reserve_inventory ->
            commands = [
              ReserveInventoryCommand.new(%{
                order_id: saga.order_id,
                items: saga.items
              })
            ]

            {:ok, commands}

          :process_payment ->
            commands = [
              ProcessPaymentCommand.new(%{
                order_id: saga.order_id,
                customer_id: saga.customer_id || saga.user_id,
                amount: saga.total_amount
              })
            ]

            {:ok, commands}

          :arrange_shipping ->
            commands = [
              ArrangeShippingCommand.new(%{
                order_id: saga.order_id,
                shipping_address: saga.shipping_address,
                items: saga.items
              })
            ]

            {:ok, commands}

          :confirm_order ->
            commands = [
              ConfirmOrderCommand.new(%{
                order_id: saga.order_id
              })
            ]

            {:ok, commands}

          _ ->
            {:ok, []}
        end
    end
  end

  # SagaBase behavior implementation
  def start(saga_id, initial_data) do
    saga = %{saga_id: saga_id}

    Map.merge(saga, %{
      order_id: initial_data.order_id,
      customer_id: initial_data.customer_id,
      items: initial_data.items,
      total_amount: initial_data.total_amount,
      shipping_address: initial_data.shipping_address,
      # サガ固有の状態
      inventory_reserved: false,
      payment_processed: false,
      shipping_arranged: false,
      order_confirmed: false
    })
  end

  @impl true
  def handle_event(event, saga) do
    case event.event_type do
      "inventory_reserved" ->
        # 在庫予約成功 -> 支払い処理へ
        updated_saga = %{saga | inventory_reserved: true, current_step: :process_payment}

        commands = [
          ProcessPaymentCommand.new(%{
            order_id: saga.order_id,
            customer_id: saga.customer_id || saga.user_id,
            amount: saga.total_amount
          })
        ]

        {:ok, commands}

      "payment_processed" ->
        # 支払い成功 -> 配送手配へ
        updated_saga = %{saga | payment_processed: true, current_step: :arrange_shipping}

        commands = [
          ArrangeShippingCommand.new(%{
            order_id: saga.order_id,
            shipping_address: saga.shipping_address,
            items: saga.items
          })
        ]

        {:ok, commands}

      "shipping_arranged" ->
        # 配送手配成功 -> 注文確定
        updated_saga = %{saga | shipping_arranged: true, current_step: :confirm_order}

        commands = [
          ConfirmOrderCommand.new(%{
            order_id: saga.order_id
          })
        ]

        {:ok, commands}

      "order_confirmed" ->
        # すべて成功 -> サガ完了
        updated_saga = %{saga | order_confirmed: true, state: :completed}
        {:ok, []}

      # 失敗ケース
      "inventory_reservation_failed" ->
        # 在庫予約失敗 -> 注文キャンセル
        {:error, "Insufficient inventory"}

      "payment_failed" ->
        # 支払い失敗 -> 補償処理開始
        {:error, "Payment processing failed"}

      "shipping_failed" ->
        # 配送手配失敗 -> 補償処理開始
        {:error, "Shipping arrangement failed"}

      # 補償処理のイベント
      "inventory_released" when saga.state == :compensating ->
        # 在庫解放完了
        check_compensation_completion(saga)

      "payment_refunded" when saga.state == :compensating ->
        # 返金完了
        check_compensation_completion(saga)

      "shipping_cancelled" when saga.state == :compensating ->
        # 配送キャンセル完了
        check_compensation_completion(saga)

      _ ->
        # その他のイベントは無視
        {:ok, []}
    end
  end

  @impl true
  def get_compensation_commands(saga) do
    commands = []

    # 完了したステップを逆順に補償
    commands =
      if saga.shipping_arranged do
        [CancelShippingCommand.new(%{order_id: saga.order_id}) | commands]
      else
        commands
      end

    commands =
      if saga.payment_processed do
        [
          RefundPaymentCommand.new(%{
            order_id: saga.order_id,
            amount: saga.total_amount
          })
          | commands
        ]
      else
        commands
      end

    commands =
      if saga.inventory_reserved do
        [
          ReleaseInventoryCommand.new(%{
            order_id: saga.order_id,
            items: saga.items
          })
          | commands
        ]
      else
        commands
      end

    # 最後に注文をキャンセル
    [CancelOrderCommand.new(%{order_id: saga.order_id}) | commands]
  end

  @impl true
  def completed?(saga) do
    saga.state == :completed
  end

  @impl true
  def failed?(saga) do
    saga.state == :failed
  end

  # Private functions

  defp check_compensation_completion(saga) do
    # すべての補償が完了したかチェック
    all_compensated =
      (!saga.inventory_reserved || has_compensation_event?(saga, "inventory_released")) &&
        (!saga.payment_processed || has_compensation_event?(saga, "payment_refunded")) &&
        (!saga.shipping_arranged || has_compensation_event?(saga, "shipping_cancelled"))

    if all_compensated do
      # 補償完了
      {:ok, []}
    else
      # まだ補償中
      {:ok, []}
    end
  end

  defp has_compensation_event?(saga, event_type) do
    Enum.any?(saga.processed_events, fn {_, event} ->
      event.event_type == event_type
    end)
  end
end
