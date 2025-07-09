defmodule QueryService.Infrastructure.Projections.OrderProjection do
  @moduledoc """
  注文プロジェクション

  注文関連のイベントを処理し、Read Model を更新します
  """

  alias QueryService.Infrastructure.Repositories.OrderRepository
  alias QueryService.Infrastructure.Cache

  alias Shared.Domain.Events.OrderEvents.{
    OrderCreated,
    OrderConfirmed,
    OrderPaymentProcessed,
    OrderCancelled,
    OrderItemReserved
  }

  require Logger

  @doc """
  イベントを処理する
  """
  def handle_event(%OrderCreated{} = event) do
    attrs = %{
      id: event.id.value,
      user_id: event.user_id.value,
      total_amount: Decimal.new(to_string(event.total_amount.amount)),
      currency: event.total_amount.currency,
      status: "pending",
      items: Enum.map(event.items, &transform_item/1),
      created_at: event.created_at,
      updated_at: event.created_at
    }

    case OrderRepository.create(attrs) do
      {:ok, order} ->
        Logger.info("Order projection created: #{order.id}")
        # キャッシュを無効化
        Cache.delete_pattern("orders:*")
        {:ok, order}

      {:error, reason} ->
        Logger.error("Failed to create order projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%OrderConfirmed{} = event) do
    attrs = %{
      status: "confirmed",
      confirmed_at: event.confirmed_at,
      updated_at: event.confirmed_at
    }

    update_order(event.id.value, attrs)
  end

  def handle_event(%OrderPaymentProcessed{} = event) do
    attrs = %{
      status: "payment_processed",
      payment_id: event.payment_id,
      payment_processed_at: event.processed_at,
      updated_at: event.processed_at
    }

    update_order(event.order_id.value, attrs)
  end

  def handle_event(%OrderCancelled{} = event) do
    attrs = %{
      status: "cancelled",
      cancellation_reason: event.reason,
      cancelled_at: event.cancelled_at,
      updated_at: event.cancelled_at
    }

    update_order(event.id.value, attrs)
  end

  def handle_event(%OrderItemReserved{} = event) do
    # 在庫予約イベント
    Logger.debug("Order item reserved: #{event.order_id.value} - #{event.product_id}")
    :ok
  end

  def handle_event(_event) do
    # 他のイベントは無視
    :ok
  end

  @doc """
  すべての注文プロジェクションをクリアする
  """
  def clear_all do
    case OrderRepository.delete_all() do
      {:ok, _} ->
        Logger.info("All order projections cleared")
        Cache.delete_pattern("orders:*")
        :ok

      {:error, reason} ->
        Logger.error("Failed to clear order projections: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp transform_item(item) do
    %{
      product_id: item.product_id,
      product_name: item.product_name,
      quantity: item.quantity,
      unit_price: Decimal.new(to_string(item.unit_price)),
      subtotal:
        Decimal.mult(
          Decimal.new(to_string(item.unit_price)),
          Decimal.new(to_string(item.quantity))
        )
    }
  end

  defp update_order(order_id, attrs) do
    case OrderRepository.update(order_id, attrs) do
      {:ok, order} ->
        Logger.info("Order projection updated: #{order.id}")
        # キャッシュを無効化
        Cache.delete("order:#{order.id}")
        Cache.delete_pattern("orders:*")
        {:ok, order}

      {:error, reason} ->
        Logger.error("Failed to update order projection: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
