defmodule CommandService.Application.Handlers.SagaCommandHandler do
  @moduledoc """
  サガコマンドハンドラー

  サガから発行されるコマンドを処理します
  """

  alias CommandService.Domain.Aggregates.{OrderAggregate, ProductAggregate}
  alias CommandService.Infrastructure.{UnitOfWork, RepositoryContext}
  alias Shared.Infrastructure.EventBus
  alias Shared.Domain.Events.OrderEvents
  alias Shared.Domain.ValueObjects.{EntityId, Money}
  alias Shared.Telemetry.Span

  require Logger

  @doc """
  在庫予約コマンドを処理する
  """
  def handle_reserve_inventory(command) do
    Span.with_span "saga_command.reserve_inventory", command do
      with {:ok, order_id} <- validate_entity_id(command.order_id),
           {:ok, product_id} <- validate_entity_id(command.product_id) do
        UnitOfWork.transaction(fn context ->
          # 在庫確認と予約のロジック（実際の実装では ProductAggregate で処理）
          # ここではシミュレーション
          event =
            OrderEvents.OrderItemReserved.new(%{
              order_id: order_id,
              product_id: product_id,
              quantity: command.quantity,
              reserved_at: DateTime.utc_now()
            })

          EventBus.publish(event)
          {:ok, %{reserved: true}}
        end)
      end
    end
  end

  @doc """
  支払い処理コマンドを処理する
  """
  def handle_process_payment(command) do
    Span.with_span "saga_command.process_payment", command do
      with {:ok, order_id} <- validate_entity_id(command.order_id),
           {:ok, amount} <- Money.new(command.amount) do
        UnitOfWork.transaction(fn context ->
          # 支払い処理のロジック（実際の実装では決済サービスと連携）
          payment_id = UUID.uuid4()

          event =
            OrderEvents.OrderPaymentProcessed.new(%{
              order_id: order_id,
              amount: amount,
              payment_id: payment_id,
              processed_at: DateTime.utc_now()
            })

          EventBus.publish(event)
          {:ok, %{payment_id: payment_id}}
        end)
      end
    end
  end

  @doc """
  配送手配コマンドを処理する
  """
  def handle_arrange_shipping(command) do
    Span.with_span "saga_command.arrange_shipping", command do
      with {:ok, order_id} <- validate_entity_id(command.order_id) do
        UnitOfWork.transaction(fn context ->
          # 配送手配のロジック（実際の実装では配送サービスと連携）
          shipping_id = UUID.uuid4()

          # イベント定義がまだないのでマップで代用
          event = %{
            event_type: "shipping_arranged",
            order_id: order_id,
            shipping_id: shipping_id,
            items: command.items,
            arranged_at: DateTime.utc_now()
          }

          EventBus.publish(event)
          {:ok, %{shipping_id: shipping_id}}
        end)
      end
    end
  end

  @doc """
  注文確定コマンドを処理する
  """
  def handle_confirm_order(command) do
    Span.with_span "saga_command.confirm_order", command do
      with {:ok, order_id} <- validate_entity_id(command.order_id) do
        UnitOfWork.transaction(fn context ->
          # 注文アグリゲートを読み込んで確定する
          case RepositoryContext.get_repository(:order).find_by_id(order_id) do
            {:ok, order} ->
              case OrderAggregate.confirm(order) do
                {:ok, updated_order} ->
                  RepositoryContext.get_repository(:order).save(updated_order)
                  EventBus.publish_all(updated_order.uncommitted_events)
                  {:ok, %{confirmed: true}}

                {:error, reason} ->
                  {:error, reason}
              end

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end
    end
  end

  @doc """
  在庫解放コマンドを処理する（補償）
  """
  def handle_release_inventory(command) do
    Span.with_span "saga_command.release_inventory", command do
      with {:ok, order_id} <- validate_entity_id(command.order_id),
           {:ok, product_id} <- validate_entity_id(command.product_id) do
        Logger.info("Releasing inventory for order #{order_id}, product #{product_id}")

        # 在庫解放のロジック
        event = %{
          event_type: "inventory_released",
          order_id: order_id,
          product_id: product_id,
          released_at: DateTime.utc_now()
        }

        EventBus.publish(event)
        {:ok, %{released: true}}
      end
    end
  end

  @doc """
  支払い返金コマンドを処理する（補償）
  """
  def handle_refund_payment(command) do
    Span.with_span "saga_command.refund_payment", command do
      with {:ok, order_id} <- validate_entity_id(command.order_id) do
        Logger.info("Refunding payment for order #{order_id}, payment #{command.payment_id}")

        # 返金処理のロジック
        event = %{
          event_type: "payment_refunded",
          order_id: order_id,
          payment_id: command.payment_id,
          amount: command.amount,
          refunded_at: DateTime.utc_now()
        }

        EventBus.publish(event)
        {:ok, %{refunded: true}}
      end
    end
  end

  @doc """
  配送キャンセルコマンドを処理する（補償）
  """
  def handle_cancel_shipping(command) do
    Span.with_span "saga_command.cancel_shipping", command do
      with {:ok, order_id} <- validate_entity_id(command.order_id) do
        Logger.info("Cancelling shipping for order #{order_id}, shipping #{command.shipping_id}")

        # 配送キャンセルのロジック
        event = %{
          event_type: "shipping_cancelled",
          order_id: order_id,
          shipping_id: command.shipping_id,
          cancelled_at: DateTime.utc_now()
        }

        EventBus.publish(event)
        {:ok, %{cancelled: true}}
      end
    end
  end

  @doc """
  注文キャンセルコマンドを処理する（補償）
  """
  def handle_cancel_order(command) do
    Span.with_span "saga_command.cancel_order", command do
      with {:ok, order_id} <- validate_entity_id(command.order_id) do
        UnitOfWork.transaction(fn context ->
          case RepositoryContext.get_repository(:order).find_by_id(order_id) do
            {:ok, order} ->
              case OrderAggregate.cancel(order, command.reason) do
                {:ok, updated_order} ->
                  RepositoryContext.get_repository(:order).save(updated_order)
                  EventBus.publish_all(updated_order.uncommitted_events)
                  {:ok, %{cancelled: true}}

                {:error, reason} ->
                  {:error, reason}
              end

            {:error, reason} ->
              # 注文が見つからない場合もキャンセル済みとして扱う
              Logger.warn("Order not found for cancellation: #{order_id}")
              {:ok, %{cancelled: true}}
          end
        end)
      end
    end
  end

  # Private functions

  defp validate_entity_id(id) when is_binary(id) do
    EntityId.from_string(id)
  end

  defp validate_entity_id(%EntityId{} = id), do: {:ok, id}
  defp validate_entity_id(_), do: {:error, "Invalid entity ID"}
end
