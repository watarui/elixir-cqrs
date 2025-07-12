defmodule ClientService.GraphQL.Resolvers.OrderResolverPubsub do
  @moduledoc """
  注文関連の GraphQL リゾルバー (PubSub版)
  """

  alias ClientService.Infrastructure.{RemoteCommandBus, RemoteQueryBus}
  alias Shared.Domain.Errors.{NotFoundError, BusinessRuleError}

  require Logger

  @doc """
  注文を作成（SAGAを開始）
  """
  def create_order(_parent, %{input: input}, _resolution) do
    command = %{
      __struct__: "CommandService.Application.Commands.OrderCommands.CreateOrder",
      command_type: "order.create",
      user_id: input.user_id,
      items: Enum.map(input.items, &transform_order_item/1),
      metadata: %{}
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, %{order_id: order_id, saga_id: saga_id}} ->
        # SAGAが開始され、注文が作成された
        # 注文詳細を取得して返す
        order = %{
          id: order_id,
          user_id: input.user_id,
          # 初期状態はpending
          status: :pending,
          total_amount: calculate_total_amount(input.items),
          items: Enum.map(input.items, &transform_input_item/1),
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        Logger.info("Order created with id: #{order_id}, saga_id: #{saga_id}")
        {:ok, %{success: true, order: order, message: "Order created successfully"}}

      {:error, error_module, context} when is_atom(error_module) ->
        # 構造化されたエラーを返す
        {:error, error_module, context}

      {:error, reason} ->
        Logger.error("Failed to create order: #{inspect(reason)}")

        {:error, BusinessRuleError,
         %{rule: "order_creation_failed", context: %{reason: inspect(reason)}}}
    end
  end

  @doc """
  注文を取得
  """
  def get_order(_parent, %{id: id}, _resolution) do
    query = %{
      __struct__: "QueryService.Application.Queries.OrderQueries.GetOrder",
      query_type: "order.get",
      id: id,
      metadata: nil
    }

    case RemoteQueryBus.send_query(query) do
      {:ok, order} ->
        {:ok, transform_order(order)}

      {:error, :not_found} ->
        {:error, NotFoundError, %{resource: "Order", id: id}}

      {:error, reason} ->
        Logger.error("Failed to get order: #{inspect(reason)}")

        {:error, BusinessRuleError,
         %{rule: "order_retrieval_failed", context: %{reason: inspect(reason)}}}
    end
  end

  @doc """
  注文一覧を取得
  """
  def list_orders(_parent, args, _resolution) do
    # ページ番号から offset を計算
    page = Map.get(args, :page, 1)
    page_size = Map.get(args, :page_size, 20)
    offset = (page - 1) * page_size

    query = %{
      __struct__: "QueryService.Application.Queries.OrderQueries.ListOrders",
      query_type: "order.list",
      limit: page_size,
      offset: offset,
      user_id: Map.get(args, :user_id),
      status: Map.get(args, :status),
      metadata: nil
    }

    case RemoteQueryBus.send_query(query) do
      {:ok, orders} ->
        {:ok, Enum.map(orders, &transform_order/1)}

      {:error, reason} ->
        Logger.error("Failed to list orders: #{inspect(reason)}")

        {:error, BusinessRuleError,
         %{rule: "order_listing_failed", context: %{reason: inspect(reason)}}}
    end
  end

  @doc """
  ユーザーの注文一覧を取得
  """
  def list_user_orders(_parent, %{user_id: user_id} = args, _resolution) do
    page = Map.get(args, :page, 1)
    page_size = Map.get(args, :page_size, 20)
    offset = (page - 1) * page_size

    query = %{
      __struct__: "QueryService.Application.Queries.OrderQueries.ListUserOrders",
      query_type: "order.list_by_user",
      user_id: user_id,
      limit: page_size,
      offset: offset,
      metadata: nil
    }

    case RemoteQueryBus.send_query(query) do
      {:ok, orders} ->
        {:ok, Enum.map(orders, &transform_order/1)}

      {:error, reason} ->
        Logger.error("Failed to list user orders: #{inspect(reason)}")

        {:error, BusinessRuleError,
         %{
           rule: "user_order_listing_failed",
           context: %{reason: inspect(reason), user_id: user_id}
         }}
    end
  end

  # プライベート関数

  defp transform_order_item(item) do
    %{
      product_id: item.product_id,
      product_name: item.product_name,
      quantity: item.quantity,
      # Decimal変換を削除
      unit_price: item.unit_price
    }
  end

  defp transform_input_item(item) do
    %{
      product_id: item.product_id,
      product_name: item.product_name,
      quantity: item.quantity,
      unit_price: item.unit_price,
      subtotal: Decimal.mult(Decimal.new(item.unit_price), Decimal.new(item.quantity))
    }
  end

  defp calculate_total_amount(items) do
    items
    |> Enum.reduce(Decimal.new(0), fn item, acc ->
      subtotal = Decimal.mult(item.unit_price, item.quantity)
      Decimal.add(acc, subtotal)
    end)
  end

  defp transform_order(order) do
    %{
      id: order.id,
      user_id: order.user_id,
      status: String.to_atom(order.status),
      total_amount: order.total_amount,
      items: Enum.map(order.items || [], &transform_order_item_from_read/1),
      created_at: ensure_datetime(order.inserted_at),
      updated_at: ensure_datetime(order.updated_at),
      saga_id: order.saga_id,
      saga_status: order.saga_status && String.to_atom(order.saga_status),
      saga_current_step: order.saga_current_step,
      payment_id: order.payment_id,
      shipping_id: order.shipping_id
    }
  end

  defp transform_order_item_from_read(item) do
    %{
      product_id: item["product_id"] || item[:product_id],
      product_name: item["product_name"] || item[:product_name],
      quantity: item["quantity"] || item[:quantity],
      unit_price: Decimal.new(item["unit_price"] || item[:unit_price] || "0"),
      subtotal: Decimal.new(item["subtotal"] || item[:subtotal] || "0")
    }
  end

  defp ensure_datetime(%DateTime{} = datetime), do: datetime

  defp ensure_datetime(%NaiveDateTime{} = naive_datetime) do
    DateTime.from_naive!(naive_datetime, "Etc/UTC")
  end

  defp ensure_datetime(nil), do: nil
end
