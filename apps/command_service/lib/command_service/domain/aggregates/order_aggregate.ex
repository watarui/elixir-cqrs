defmodule CommandService.Domain.Aggregates.OrderAggregate do
  @moduledoc """
  注文アグリゲート

  注文に関するビジネスロジックを管理します
  """

  defstruct [
    :id,
    :customer_id,
    :items,
    :subtotal,
    :tax_amount,
    :shipping_cost,
    :total_amount,
    :status,
    :shipping_address,
    :payment_info,
    :tracking_number,
    :version,
    :pending_events,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          customer_id: String.t() | nil,
          items: list(map()),
          subtotal: Decimal.t() | nil,
          tax_amount: Decimal.t() | nil,
          shipping_cost: Decimal.t() | nil,
          total_amount: Decimal.t() | nil,
          status: String.t() | nil,
          shipping_address: map() | nil,
          payment_info: map() | nil,
          tracking_number: String.t() | nil,
          version: non_neg_integer(),
          pending_events: list(map()),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  # 定数
  # 10%
  @tax_rate Decimal.new("0.10")
  @free_shipping_threshold Decimal.new("5000")
  @standard_shipping_cost Decimal.new("500")

  @spec new() :: t()
  def new do
    %__MODULE__{
      id: nil,
      customer_id: nil,
      items: [],
      subtotal: nil,
      tax_amount: nil,
      shipping_cost: nil,
      total_amount: nil,
      status: nil,
      shipping_address: nil,
      payment_info: nil,
      tracking_number: nil,
      version: 0,
      pending_events: [],
      created_at: nil,
      updated_at: nil
    }
  end

  @spec new(String.t()) :: t()
  def new(id) when is_binary(id) do
    %__MODULE__{new() | id: id}
  end

  @spec execute(t(), tuple()) :: {:ok, list(map())} | {:error, atom() | String.t()}
  def execute(%__MODULE__{id: nil}, {:create_order, params}) do
    # バリデーション
    with :ok <- validate_create_order_params(params),
         :ok <- validate_items_availability(params.items) do
      order_id = params.order_id || params.id || Ecto.UUID.generate()

      # 価格計算
      {subtotal, tax_amount, shipping_cost, total_amount} = calculate_order_totals(params.items)

      # 商品情報を正規化
      normalized_items = normalize_items(params.items)

      event = %{
        event_type: "order_created",
        aggregate_id: order_id,
        aggregate_type: "order",
        event_data: %{
          customer_id: params.customer_id,
          items: normalized_items,
          subtotal: subtotal,
          tax_amount: tax_amount,
          shipping_cost: shipping_cost,
          total_amount: total_amount,
          status: "pending",
          shipping_address: params.shipping_address
        },
        event_metadata: params[:metadata] || %{},
        event_version: 1,
        occurred_at: DateTime.utc_now()
      }

      {:ok, [event]}
    end
  end

  def execute(%__MODULE__{id: id} = aggregate, {:update_order, params}) when not is_nil(id) do
    # ステータスが完了または取消済みの場合は更新不可
    if aggregate.status in ["completed", "cancelled"] do
      {:error, :order_completed}
    else
      changes = build_update_changes(aggregate, params)

      if map_size(changes) == 0 do
        {:ok, []}
      else
        # ステータス遷移の検証
        if Map.has_key?(changes, :status) do
          case validate_status_transition(aggregate.status, changes.status) do
            :ok ->
              event = build_update_event(id, changes, aggregate.version + 1, params[:metadata])
              {:ok, [event]}

            error ->
              error
          end
        else
          event = build_update_event(id, changes, aggregate.version + 1, params[:metadata])
          {:ok, [event]}
        end
      end
    end
  end

  def execute(%__MODULE__{id: id} = aggregate, {:cancel_order, params}) when not is_nil(id) do
    cond do
      aggregate.status == "completed" ->
        {:error, :cannot_cancel_completed_order}

      aggregate.status == "cancelled" ->
        {:error, :order_already_cancelled}

      true ->
        event = %{
          event_type: "order_cancelled",
          aggregate_id: id,
          aggregate_type: "order",
          event_data: %{
            reason: params.reason || "Customer requested cancellation",
            status: "cancelled"
          },
          event_metadata: Map.merge(params[:metadata] || %{}, %{trigger_compensation: true}),
          event_version: aggregate.version + 1,
          occurred_at: DateTime.utc_now()
        }

        {:ok, [event]}
    end
  end

  def execute(_aggregate, _command) do
    {:error, "Invalid command"}
  end

  @spec load_from_events(list(map())) :: t()
  def load_from_events(events) do
    Enum.reduce(events, new(), &apply_event(&2, &1))
  end

  defp apply_event(aggregate, event) do
    case event.event_type do
      "order_created" ->
        %__MODULE__{
          aggregate
          | id: event.aggregate_id,
            customer_id: event.event_data.customer_id,
            items: event.event_data.items,
            subtotal: ensure_decimal_from_event(event.event_data[:subtotal]),
            tax_amount: ensure_decimal_from_event(event.event_data[:tax_amount]),
            shipping_cost: ensure_decimal_from_event(event.event_data[:shipping_cost]),
            total_amount: ensure_decimal_from_event(event.event_data.total_amount),
            status: event.event_data.status,
            shipping_address: event.event_data.shipping_address,
            created_at: Map.get(event, :occurred_at),
            updated_at: Map.get(event, :occurred_at),
            version: event.event_version
        }

      "order_updated" ->
        aggregate
        |> maybe_update(:status, event.event_data[:status])
        |> maybe_update(:shipping_address, event.event_data[:shipping_address])
        |> maybe_update(:payment_info, event.event_data[:payment_info])
        |> maybe_update(:tracking_number, event.event_data[:tracking_number])
        |> Map.put(:updated_at, Map.get(event, :occurred_at))
        |> Map.put(:version, event.event_version)

      "order_cancelled" ->
        %__MODULE__{
          aggregate
          | status: "cancelled",
            version: event.event_version
        }

      _ ->
        aggregate
    end
  end

  defp maybe_update(aggregate, _field, nil), do: aggregate
  defp maybe_update(aggregate, field, value), do: Map.put(aggregate, field, value)

  defp validate_create_order_params(params) do
    cond do
      is_nil(params.customer_id) ->
        {:error, :missing_customer}

      is_nil(params.items) || params.items == [] ->
        {:error, :no_items}

      not valid_items?(params.items) ->
        {:error, :invalid_quantity}

      is_nil(params.shipping_address) ->
        {:error, :missing_shipping_address}

      true ->
        :ok
    end
  end

  defp valid_items?(items) do
    Enum.all?(items, fn item ->
      quantity = Map.get(item, :quantity) || Map.get(item, "quantity")
      unit_price = Map.get(item, :unit_price) || Map.get(item, "unit_price")
      product_id = Map.get(item, :product_id) || Map.get(item, "product_id")

      quantity && quantity > 0 &&
        unit_price &&
        product_id && product_id != ""
    end)
  end

  defp validate_items_availability(items) do
    # 実際の実装では、在庫プロジェクションをチェック
    # ここでは簡易実装として常にOKを返す
    :ok
  end

  defp normalize_items(items) do
    Enum.map(items, fn item ->
      %{
        product_id: Map.get(item, :product_id) || Map.get(item, "product_id"),
        product_name: Map.get(item, :product_name) || Map.get(item, "product_name", ""),
        quantity: Map.get(item, :quantity) || Map.get(item, "quantity"),
        unit_price: ensure_decimal(Map.get(item, :unit_price) || Map.get(item, "unit_price")),
        discount_rate:
          ensure_decimal(Map.get(item, :discount_rate) || Map.get(item, "discount_rate", "0"))
      }
    end)
  end

  defp calculate_order_totals(items) do
    subtotal = calculate_subtotal(items)
    tax_amount = calculate_tax(subtotal)
    shipping_cost = calculate_shipping(subtotal)
    total_amount = Decimal.add(subtotal, Decimal.add(tax_amount, shipping_cost))

    {subtotal, tax_amount, shipping_cost, total_amount}
  end

  defp calculate_subtotal(items) do
    Enum.reduce(items, Decimal.new("0"), fn item, acc ->
      quantity = Decimal.new(to_string(item.quantity))
      unit_price = ensure_decimal(item.unit_price)

      # 割引の適用
      discount_rate = ensure_decimal(Map.get(item, :discount_rate, "0"))

      discounted_price =
        if Decimal.gt?(discount_rate, Decimal.new("0")) do
          discount_amount = Decimal.mult(unit_price, discount_rate)
          Decimal.sub(unit_price, discount_amount)
        else
          unit_price
        end

      subtotal = Decimal.mult(quantity, discounted_price)
      Decimal.add(acc, subtotal)
    end)
  end

  defp calculate_tax(subtotal) do
    Decimal.mult(subtotal, @tax_rate)
  end

  defp calculate_shipping(subtotal) do
    if Decimal.gte?(subtotal, @free_shipping_threshold) do
      Decimal.new("0")
    else
      @standard_shipping_cost
    end
  end

  defp ensure_decimal(%Decimal{} = d), do: d
  defp ensure_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp ensure_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp ensure_decimal(value) when is_integer(value), do: Decimal.new(to_string(value))
  defp ensure_decimal(nil), do: Decimal.new("0")
  defp ensure_decimal(_), do: Decimal.new("0")

  defp ensure_decimal_from_event(nil), do: nil
  defp ensure_decimal_from_event(value) when is_binary(value), do: Decimal.new(value)
  defp ensure_decimal_from_event(%Decimal{} = value), do: value
  defp ensure_decimal_from_event(value), do: ensure_decimal(value)

  defp build_update_changes(aggregate, params) do
    changes = %{}

    changes =
      if params[:status] && params[:status] != aggregate.status do
        Map.put(changes, :status, params[:status])
      else
        changes
      end

    changes =
      if params[:shipping_address] && params[:shipping_address] != aggregate.shipping_address do
        Map.put(changes, :shipping_address, params[:shipping_address])
      else
        changes
      end

    changes =
      if params[:payment_info] && params[:payment_info] != aggregate.payment_info do
        Map.put(changes, :payment_info, params[:payment_info])
      else
        changes
      end

    changes =
      if params[:tracking_number] && params[:tracking_number] != aggregate.tracking_number do
        Map.put(changes, :tracking_number, params[:tracking_number])
      else
        changes
      end

    changes
  end

  defp validate_status_transition(from_status, to_status) do
    valid_transitions = %{
      "pending" => ["processing", "completed", "cancelled", "payment_pending"],
      "payment_pending" => ["processing", "cancelled", "payment_failed"],
      "payment_failed" => ["cancelled", "payment_pending"],
      "processing" => ["shipped", "completed", "cancelled"],
      "shipped" => ["delivered", "returned"],
      "delivered" => ["completed", "returned"],
      "completed" => ["returned"],
      "returned" => ["refunded"],
      "refunded" => [],
      "cancelled" => []
    }

    allowed = Map.get(valid_transitions, from_status, [])

    if to_status in allowed do
      :ok
    else
      {:error, :invalid_status_transition}
    end
  end

  defp build_update_event(aggregate_id, changes, version, metadata) do
    %{
      event_type: "order_updated",
      aggregate_id: aggregate_id,
      aggregate_type: "order",
      event_data: changes,
      event_metadata: metadata || %{},
      event_version: version,
      occurred_at: DateTime.utc_now()
    }
  end

  # 公開関数
  @spec add_item(t(), map()) :: {:ok, t()} | {:error, atom()}
  def add_item(%__MODULE__{status: "pending"} = aggregate, item) do
    with :ok <- validate_item(item) do
      updated_items = aggregate.items ++ [normalize_item(item)]
      {subtotal, tax_amount, shipping_cost, total_amount} = calculate_order_totals(updated_items)

      updated_aggregate = %__MODULE__{
        aggregate
        | items: updated_items,
          subtotal: subtotal,
          tax_amount: tax_amount,
          shipping_cost: shipping_cost,
          total_amount: total_amount
      }

      {:ok, updated_aggregate}
    end
  end

  def add_item(_aggregate, _item), do: {:error, :cannot_modify_order}

  @spec remove_item(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def remove_item(%__MODULE__{status: "pending"} = aggregate, product_id) do
    updated_items = Enum.reject(aggregate.items, &(&1.product_id == product_id))

    if Enum.empty?(updated_items) do
      {:error, :cannot_remove_last_item}
    else
      {subtotal, tax_amount, shipping_cost, total_amount} = calculate_order_totals(updated_items)

      updated_aggregate = %__MODULE__{
        aggregate
        | items: updated_items,
          subtotal: subtotal,
          tax_amount: tax_amount,
          shipping_cost: shipping_cost,
          total_amount: total_amount
      }

      {:ok, updated_aggregate}
    end
  end

  def remove_item(_aggregate, _product_id), do: {:error, :cannot_modify_order}

  defp validate_item(item) do
    cond do
      is_nil(item[:product_id]) && is_nil(item["product_id"]) ->
        {:error, :missing_product_id}

      is_nil(item[:quantity]) && is_nil(item["quantity"]) ->
        {:error, :missing_quantity}

      is_nil(item[:unit_price]) && is_nil(item["unit_price"]) ->
        {:error, :missing_unit_price}

      true ->
        :ok
    end
  end

  defp normalize_item(item) do
    %{
      product_id: Map.get(item, :product_id) || Map.get(item, "product_id"),
      product_name: Map.get(item, :product_name) || Map.get(item, "product_name", ""),
      quantity: Map.get(item, :quantity) || Map.get(item, "quantity"),
      unit_price: ensure_decimal(Map.get(item, :unit_price) || Map.get(item, "unit_price")),
      discount_rate:
        ensure_decimal(Map.get(item, :discount_rate) || Map.get(item, "discount_rate", "0"))
    }
  end
end
