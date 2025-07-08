defmodule QueryService.Application.Queries.GetOrderQuery do
  @moduledoc """
  Query to get an order by ID
  """
  use QueryService.Application.Queries.BaseQuery

  defstruct id: nil, include_customer: false, include_timeline: false

  @impl true
  def validate(query) do
    if query.id && is_binary(query.id) do
      :ok
    else
      {:error, :invalid_id}
    end
  end
end

defmodule QueryService.Application.Queries.ListOrdersQuery do
  @moduledoc """
  Query to list orders with pagination and filtering
  """
  use QueryService.Application.Queries.BaseQuery

  defstruct page: 1,
            page_size: 20,
            start_date: nil,
            end_date: nil,
            min_amount: nil,
            sort_by: "created_at",
            sort_order: "desc"

  @impl true
  def validate(query) do
    cond do
      query.page < 1 -> {:error, :invalid_page}
      query.page_size < 1 || query.page_size > 100 -> {:error, :invalid_page_size}
      query.sort_order not in ["asc", "desc"] -> {:error, :invalid_sort_order}
      true -> :ok
    end
  end
end

defmodule QueryService.Application.Queries.GetOrdersByCustomerQuery do
  @moduledoc """
  Query to get orders by customer ID
  """
  use QueryService.Application.Queries.BaseQuery

  defstruct [:customer_id, :status, include_stats: false]

  @impl true
  def validate(query) do
    if query.customer_id && is_binary(query.customer_id) do
      :ok
    else
      {:error, :invalid_customer_id}
    end
  end
end

defmodule QueryService.Application.Queries.GetOrdersByStatusQuery do
  @moduledoc """
  Query to get orders by status
  """
  use QueryService.Application.Queries.BaseQuery

  defstruct [:status, :statuses, include_duration_metrics: false]

  @impl true
  def validate(query) do
    if is_nil(query.status) and (is_nil(query.statuses) or query.statuses == []) do
      {:error, :status_required}
    else
      :ok
    end
  end
end

defmodule QueryService.Application.Queries.GetOrderStatsQuery do
  @moduledoc """
  Query to get order statistics
  """
  use QueryService.Application.Queries.BaseQuery

  defstruct [:start_date, :end_date, :group_by, include_product_metrics: false]

  @impl true
  def validate(query) do
    if query.group_by && query.group_by not in ["day", "week", "month"] do
      {:error, :invalid_group_by}
    else
      :ok
    end
  end
end
