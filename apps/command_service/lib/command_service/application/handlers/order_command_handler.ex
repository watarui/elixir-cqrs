defmodule CommandService.Application.Handlers.OrderCommandHandler do
  @moduledoc """
  注文コマンドハンドラー
  """

  alias CommandService.Application.Commands.OrderCommands
  alias CommandService.Domain.Aggregates.OrderAggregate
  alias CommandService.Infrastructure.{RepositoryContext, UnitOfWork}
  alias Shared.Infrastructure.EventBus
  alias Shared.Infrastructure.Saga.SagaCoordinator

  require Logger

  @behaviour CommandService.Application.Handlers.CommandHandler

  @impl true
  def handle(%OrderCommands.CreateOrder{} = command) do
    UnitOfWork.transaction(fn _context ->
      case OrderAggregate.create(command.user_id, command.items) do
        {:ok, order} ->
          # イベントストアに保存
          repo = RepositoryContext.get_repository(:order)
          {:ok, _} = repo.save(order)

          # イベントを発行
          Enum.each(order.uncommitted_events, fn event ->
            EventBus.publish_event(event)
          end)

          # サガを開始
          saga_id = UUID.uuid4()

          saga_data = %{
            order_id: order.id.value,
            user_id: command.user_id,
            items: command.items,
            total_amount: calculate_total_amount(command.items)
          }

          case SagaCoordinator.start_saga(
                 saga_id,
                 CommandService.Domain.Sagas.OrderSaga,
                 saga_data
               ) do
            {:ok, _} ->
              Logger.info("Order saga started for order #{order.id.value}")
              {:ok, %{order_id: order.id.value, saga_id: saga_id}}

            {:error, reason} ->
              Logger.error("Failed to start order saga: #{inspect(reason)}")
              # サガの開始失敗は注文作成には影響しない
              {:ok, %{order_id: order.id.value}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @impl true
  def handle(%OrderCommands.ConfirmOrder{} = command) do
    UnitOfWork.transaction(fn context ->
      repo = RepositoryContext.get_repository(:order)

      with {:ok, order} <- repo.find_by_id(command.order_id),
           {:ok, updated_order} <- OrderAggregate.confirm(order) do
        repo.save(updated_order)
        EventBus.publish_all(updated_order.uncommitted_events)

        {:ok, %{confirmed: true}}
      end
    end)
  end

  @impl true
  def handle(%OrderCommands.CancelOrder{} = command) do
    UnitOfWork.transaction(fn context ->
      repo = RepositoryContext.get_repository(:order)

      with {:ok, order} <- repo.find_by_id(command.order_id),
           {:ok, updated_order} <- OrderAggregate.cancel(order, command.reason) do
        repo.save(updated_order)
        EventBus.publish_all(updated_order.uncommitted_events)

        {:ok, %{cancelled: true}}
      end
    end)
  end

  @impl true
  def handle(%OrderCommands.ReserveInventory{} = command) do
    UnitOfWork.transaction(fn context ->
      repo = RepositoryContext.get_repository(:order)

      with {:ok, order} <- repo.find_by_id(command.order_id),
           {:ok, results} <- reserve_all_items(order, command.items, repo) do
        {:ok, %{reserved_items: results}}
      end
    end)
  end

  defp reserve_all_items(order, items, repo) do
    results =
      Enum.map(items, fn item ->
        reserve_single_item(order, item, repo)
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, id} -> id end)}
    else
      {:error, "Failed to reserve some items: #{inspect(errors)}"}
    end
  end

  defp reserve_single_item(order, item, repo) do
    case OrderAggregate.reserve_item(order, item.product_id, item.quantity) do
      {:ok, updated_order} ->
        repo.save(updated_order)
        EventBus.publish_all(updated_order.uncommitted_events)
        {:ok, item.product_id}

      {:error, reason} ->
        {:error, {item.product_id, reason}}
    end
  end

  @impl true
  def handle(%OrderCommands.ProcessPayment{} = command) do
    UnitOfWork.transaction(fn context ->
      repo = RepositoryContext.get_repository(:order)

      with {:ok, order} <- repo.find_by_id(command.order_id),
           {:ok, updated_order} <-
             OrderAggregate.process_payment(order, command.payment_id || UUID.uuid4()) do
        repo.save(updated_order)
        EventBus.publish_all(updated_order.uncommitted_events)

        {:ok, %{payment_processed: true, payment_id: command.payment_id}}
      end
    end)
  end

  # 以下、補償用コマンドハンドラー

  @impl true
  def handle(%OrderCommands.ReleaseInventory{} = command) do
    Logger.info("Releasing inventory for order #{command.order_id}")

    # 実際の実装では ProductAggregate で在庫を戻す処理を行う
    event = %{
      event_type: "inventory_released",
      order_id: command.order_id,
      items: command.items,
      released_at: DateTime.utc_now()
    }

    EventBus.publish(event.event_type, event)
    {:ok, %{released: true}}
  end

  @impl true
  def handle(%OrderCommands.RefundPayment{} = command) do
    Logger.info("Refunding payment for order #{command.order_id}")

    # 実際の実装では決済サービスと連携して返金処理を行う
    event = %{
      event_type: "payment_refunded",
      order_id: command.order_id,
      amount: command.amount,
      refunded_at: DateTime.utc_now()
    }

    EventBus.publish(event.event_type, event)
    {:ok, %{refunded: true}}
  end

  @impl true
  def handle(%OrderCommands.CancelShipping{} = command) do
    Logger.info("Cancelling shipping for order #{command.order_id}")

    # 実際の実装では配送サービスと連携してキャンセル処理を行う
    event = %{
      event_type: "shipping_cancelled",
      order_id: command.order_id,
      cancelled_at: DateTime.utc_now()
    }

    EventBus.publish(event.event_type, event)
    {:ok, %{cancelled: true}}
  end

  @impl true
  def handle(command) do
    {:error, "Unknown order command: #{inspect(command)}"}
  end

  # Private functions

  defp calculate_total_amount(items) do
    Enum.reduce(items, Decimal.new(0), fn item, acc ->
      item_total =
        Decimal.mult(
          Decimal.new(to_string(item.unit_price)),
          Decimal.new(to_string(item.quantity))
        )

      Decimal.add(acc, item_total)
    end)
  end
end
