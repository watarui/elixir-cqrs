defmodule QueryService.Application.Handlers.OrderQueryHandler do
  @moduledoc """
  Handler for order-related queries
  """

  alias QueryService.Infrastructure.Repositories.OrderRepository

  alias QueryService.Application.Queries.{
    GetOrderQuery,
    ListOrdersQuery,
    GetOrdersByCustomerQuery,
    GetOrdersByStatusQuery,
    GetOrderStatsQuery
  }

  def handle(%GetOrderQuery{id: id} = query) do
    case OrderRepository.find_by_id(id) do
      {:ok, order} ->
        order = enrich_order(order, query)
        {:ok, order}

      error ->
        error
    end
  end

  def handle(%ListOrdersQuery{} = query) do
    # Get paginated orders
    {:ok, {orders, total_count}} =
      OrderRepository.list_paginated(%{
        page: query.page,
        page_size: query.page_size
      })

    # Apply filters
    orders = apply_filters(orders, query)

    # Apply sorting
    orders = apply_sorting(orders, query)

    {:ok,
     %{
       data: orders,
       metadata: %{
         page: query.page,
         page_size: query.page_size,
         total_count: total_count,
         total_pages: ceil(total_count / query.page_size)
       }
     }}
  end

  def handle(%GetOrdersByCustomerQuery{customer_id: customer_id} = query) do
    {:ok, orders} = OrderRepository.find_by_customer_id(customer_id)

    # Apply status filter if provided
    orders =
      if query.status do
        Enum.filter(orders, fn order ->
          Atom.to_string(order.status) == query.status
        end)
      else
        orders
      end

    result = %{data: orders}

    # Add statistics if requested
    result =
      if query.include_stats do
        stats = calculate_customer_stats(orders)
        Map.put(result, :stats, stats)
      else
        result
      end

    {:ok, result}
  end

  def handle(%GetOrdersByStatusQuery{} = query) do
    statuses = get_statuses_list(query)

    # Get orders for each status
    orders =
      Enum.flat_map(statuses, fn status ->
        {:ok, status_orders} = OrderRepository.list_by_status(String.to_atom(status))
        status_orders
      end)

    result = %{data: orders}

    # Add duration metrics if requested
    result =
      if query.include_duration_metrics do
        metrics = calculate_duration_metrics(orders)
        Map.put(result, :metrics, metrics)
      else
        result
      end

    {:ok, result}
  end

  def handle(%GetOrderStatsQuery{} = query) do
    {:ok, base_stats} = OrderRepository.get_statistics()

    stats = %{
      total_orders: base_stats.total_count,
      completed_orders: Map.get(base_stats.status_counts, "completed", 0),
      total_revenue: to_decimal(base_stats.total_revenue),
      average_order_value: to_decimal(base_stats.average_order_value),
      status_distribution: format_status_distribution(base_stats.status_counts)
    }

    # Add time period if specified
    stats =
      if query.start_date && query.end_date do
        Map.put(stats, :period, %{
          start_date: query.start_date,
          end_date: query.end_date
        })
      else
        stats
      end

    # Add time series if grouping requested
    stats =
      if query.group_by do
        time_series = generate_time_series(query)
        Map.put(stats, :time_series, time_series)
      else
        stats
      end

    # Add product metrics if requested
    stats =
      if query.include_product_metrics do
        product_metrics = calculate_product_metrics()
        Map.put(stats, :top_products, product_metrics)
      else
        stats
      end

    {:ok, stats}
  end

  # Private functions

  defp enrich_order(order, query) do
    order =
      if query.include_customer do
        # In a real implementation, would fetch customer data
        Map.put(order, :customer, %{id: order.customer_id, name: "Test Customer"})
      else
        order
      end

    order =
      if query.include_timeline do
        # Generate timeline from order status changes
        timeline = generate_order_timeline(order)
        Map.put(order, :timeline, timeline)
      else
        order
      end

    order
  end

  defp apply_filters(orders, query) do
    orders
    |> filter_by_date_range(query.start_date, query.end_date)
    |> filter_by_min_amount(query.min_amount)
  end

  defp filter_by_date_range(orders, nil, nil), do: orders

  defp filter_by_date_range(orders, start_date, end_date) do
    Enum.filter(orders, fn order ->
      in_range = true

      in_range =
        in_range && (is_nil(start_date) || DateTime.compare(order.created_at, start_date) != :lt)

      in_range =
        in_range && (is_nil(end_date) || DateTime.compare(order.created_at, end_date) != :gt)

      in_range
    end)
  end

  defp filter_by_min_amount(orders, nil), do: orders

  defp filter_by_min_amount(orders, min_amount) do
    Enum.filter(orders, fn order ->
      Decimal.compare(order.total_amount, min_amount) != :lt
    end)
  end

  defp apply_sorting(orders, %{sort_by: "total_amount", sort_order: order}) do
    Enum.sort_by(orders, & &1.total_amount, fn a, b ->
      if order == "desc", do: Decimal.compare(a, b) != :lt, else: Decimal.compare(a, b) == :lt
    end)
  end

  defp apply_sorting(orders, %{sort_by: _field, sort_order: order}) do
    # Default to sorting by created_at
    if order == "desc" do
      Enum.sort_by(orders, & &1.created_at, {:desc, DateTime})
    else
      Enum.sort_by(orders, & &1.created_at, {:asc, DateTime})
    end
  end

  defp get_statuses_list(%{status: status}) when not is_nil(status), do: [status]
  defp get_statuses_list(%{statuses: statuses}) when is_list(statuses), do: statuses
  defp get_statuses_list(_), do: []

  defp calculate_customer_stats(orders) do
    total_orders = length(orders)
    completed_orders = Enum.filter(orders, &(&1.status == :completed))

    total_spent =
      Enum.reduce(completed_orders, Decimal.new("0"), fn order, acc ->
        Decimal.add(acc, order.total_amount)
      end)

    avg_order_value =
      if length(completed_orders) > 0 do
        Decimal.div(total_spent, Decimal.new(length(completed_orders)))
      else
        Decimal.new("0")
      end

    %{
      total_orders: total_orders,
      total_spent: total_spent,
      average_order_value: avg_order_value
    }
  end

  defp calculate_duration_metrics(_orders) do
    # Mock implementation
    %{
      # 1 hour in seconds
      average_duration: 3600,
      # 30 minutes
      min_duration: 1800,
      # 2 hours
      max_duration: 7200
    }
  end

  defp format_status_distribution(status_counts) do
    %{
      pending: Map.get(status_counts, "pending", 0),
      processing: Map.get(status_counts, "processing", 0),
      completed: Map.get(status_counts, "completed", 0),
      cancelled: Map.get(status_counts, "cancelled", 0),
      failed: Map.get(status_counts, "failed", 0)
    }
  end

  defp generate_order_timeline(order) do
    [
      %{
        timestamp: order.created_at,
        status: "created",
        description: "Order created"
      },
      %{
        timestamp: order.updated_at || order.created_at,
        status: Atom.to_string(order.status),
        description: "Order #{order.status}"
      }
    ]
  end

  defp generate_time_series(_query) do
    # Mock time series data
    [
      %{
        date: Date.utc_today(),
        order_count: 10,
        revenue: Decimal.new("1000.00")
      },
      %{
        date: Date.add(Date.utc_today(), -1),
        order_count: 8,
        revenue: Decimal.new("800.00")
      }
    ]
  end

  defp calculate_product_metrics do
    # Mock product metrics
    [
      %{
        product_id: Ecto.UUID.generate(),
        quantity_sold: 100,
        revenue: Decimal.new("10000.00")
      },
      %{
        product_id: Ecto.UUID.generate(),
        quantity_sold: 50,
        revenue: Decimal.new("5000.00")
      }
    ]
  end

  defp to_decimal(nil), do: Decimal.new("0")

  defp to_decimal(value) when is_float(value) do
    value
    |> Float.to_string()
    |> Decimal.new()
  end

  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_binary(value), do: Decimal.new(value)
end
