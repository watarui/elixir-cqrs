defmodule QueryService.Infrastructure.Repositories.OrderRepository do
  @moduledoc """
  Order Repository Implementation for Query Service
  """

  @behaviour QueryService.Domain.Repositories.OrderRepository

  import Ecto.Query

  alias QueryService.Domain.Models.Order
  alias QueryService.Infrastructure.Database.Repo
  alias QueryService.Infrastructure.Database.Schemas.OrderSchema
  alias QueryService.Infrastructure.Repositories.CachedRepository

  @impl true
  def find_by_id(id) when is_binary(id) do
    CachedRepository.cached_find_by_id(__MODULE__, id)
  end

  # キャッシュを使わない内部実装
  def find_by_id_uncached(id) when is_binary(id) do
    case Repo.get(OrderSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_model(schema)}
    end
  end

  @impl true
  def find_by_customer_id(customer_id) when is_binary(customer_id) do
    query =
      from(o in OrderSchema,
        where: o.customer_id == ^customer_id,
        order_by: [desc: o.inserted_at]
      )

    results = Repo.all(query)
    models = Enum.map(results, &schema_to_model/1)
    {:ok, models}
  end

  @impl true
  def list do
    CachedRepository.cached_list(__MODULE__)
  end

  # キャッシュを使わない内部実装
  def list_uncached do
    query = from(o in OrderSchema, order_by: [desc: o.inserted_at])
    results = Repo.all(query)
    models = Enum.map(results, &schema_to_model/1)
    {:ok, models}
  end

  @impl true
  def list_by_status(status) when is_atom(status) do
    status_string = Atom.to_string(status)

    query =
      from(o in OrderSchema,
        where: o.status == ^status_string,
        order_by: [desc: o.inserted_at]
      )

    results = Repo.all(query)
    models = Enum.map(results, &schema_to_model/1)
    {:ok, models}
  end

  @impl true
  def list_paginated(%{page: page, page_size: page_size}) do
    offset = (page - 1) * page_size

    query =
      from(o in OrderSchema,
        limit: ^page_size,
        offset: ^offset,
        order_by: [desc: o.inserted_at]
      )

    results = Repo.all(query)
    models = Enum.map(results, &schema_to_model/1)
    total_count = count_all()
    {:ok, {models, total_count}}
  end

  @impl true
  def count do
    total_count = count_all()
    {:ok, total_count}
  end

  @impl true
  def count_by_status(status) when is_atom(status) do
    status_string = Atom.to_string(status)
    query = from(o in OrderSchema, where: o.status == ^status_string, select: count(o.id))
    count = Repo.one(query)
    {:ok, count}
  end

  @impl true
  def exists?(id) do
    query = from(o in OrderSchema, where: o.id == ^id, select: count(o.id))
    Repo.one(query) > 0
  end

  @impl true
  def get_statistics do
    total_count = count_all()

    # ステータス別の統計を取得
    status_counts_query =
      from(o in OrderSchema,
        group_by: o.status,
        select: {o.status, count(o.id)}
      )

    status_counts = Repo.all(status_counts_query) |> Map.new()

    # 売上統計を取得
    revenue_stats_query =
      from(o in OrderSchema,
        where: o.status not in ["cancelled", "failed"],
        select: %{
          total_revenue: sum(o.total_amount),
          avg_order_value: avg(o.total_amount),
          total_orders: count(o.id)
        }
      )

    revenue_stats = Repo.one(revenue_stats_query)

    statistics = %{
      total_count: total_count,
      status_counts: status_counts,
      total_revenue: Decimal.to_float(revenue_stats.total_revenue || Decimal.new("0")),
      average_order_value: Decimal.to_float(revenue_stats.avg_order_value || Decimal.new("0")),
      successful_orders: revenue_stats.total_orders || 0
    }

    {:ok, statistics}
  end

  @impl true
  def find_by_date_range(start_date, end_date) do
    query =
      from(o in OrderSchema,
        where: o.inserted_at >= ^start_date and o.inserted_at <= ^end_date,
        order_by: [desc: o.inserted_at]
      )

    results = Repo.all(query)
    models = Enum.map(results, &schema_to_model/1)
    {:ok, models}
  end

  # プライベートヘルパー関数
  defp count_all do
    query = from(o in OrderSchema, select: count(o.id))
    Repo.one(query)
  end

  defp schema_to_model(schema) do
    Order.new(%{
      id: schema.id,
      customer_id: schema.customer_id,
      status: schema.status,
      items: parse_items(schema.items),
      subtotal: schema.subtotal,
      tax_amount: schema.tax_amount,
      shipping_cost: schema.shipping_cost,
      total_amount: schema.total_amount,
      shipping_address: schema.shipping_address,
      payment_status: schema.payment_status,
      saga_state: schema.saga_state,
      created_at: to_datetime(schema.inserted_at),
      updated_at: to_datetime(schema.updated_at)
    })
  end

  defp parse_items(nil), do: []

  defp parse_items(items) when is_list(items) do
    Enum.map(items, fn item ->
      %{
        product_id: item["product_id"] || item[:product_id],
        product_name: item["product_name"] || item[:product_name],
        quantity: item["quantity"] || item[:quantity],
        unit_price: parse_decimal(item["unit_price"] || item[:unit_price]),
        subtotal: parse_decimal(item["subtotal"] || item[:subtotal])
      }
    end)
  end

  defp parse_decimal(nil), do: Decimal.new("0")
  defp parse_decimal(%Decimal{} = decimal), do: decimal
  defp parse_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp parse_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp parse_decimal(value) when is_integer(value), do: Decimal.new(value)

  # タイムスタンプ変換ヘルパー関数
  defp to_datetime(nil), do: nil
  defp to_datetime(%NaiveDateTime{} = naive_dt), do: DateTime.from_naive!(naive_dt, "Etc/UTC")
  defp to_datetime(%DateTime{} = dt), do: dt
end
