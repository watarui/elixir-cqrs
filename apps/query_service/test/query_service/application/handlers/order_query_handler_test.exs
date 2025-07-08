defmodule QueryService.Application.Handlers.OrderQueryHandlerTest do
  use ExUnit.Case, async: false

  alias QueryService.Application.Handlers.OrderQueryHandler

  alias QueryService.Application.Queries.{
    GetOrderQuery,
    GetOrdersByCustomerQuery,
    GetOrdersByStatusQuery,
    GetOrderStatsQuery,
    ListOrdersQuery
  }

  alias Ecto.Adapters.SQL.Sandbox
  alias QueryService.Domain.Models.Order
  alias QueryService.Infrastructure.Database.Repo
  alias QueryService.Infrastructure.Repositories.OrderRepository

  # import ElixirCqrs.Factory
  # import ElixirCqrs.TestHelpers

  setup do
    :ok = Sandbox.checkout(Repo)
    # Don't create shared test data
    :ok
  end

  describe "handle GetOrderQuery" do
    test "successfully retrieves an existing order" do
      # Arrange
      order = create_order(%{})
      query = GetOrderQuery.new(%{id: order.id})

      # Act
      result = OrderQueryHandler.handle(query)

      # Assert
      assert {:ok, retrieved_order} = result
      assert retrieved_order.id == order.id
      assert retrieved_order.customer_id == order.customer_id
      assert length(retrieved_order.items) == length(order.items)
    end

    test "returns error for non-existent order" do
      # Arrange
      query = GetOrderQuery.new(%{id: Ecto.UUID.generate()})

      # Act
      result = OrderQueryHandler.handle(query)

      # Assert
      assert {:error, :not_found} = result
    end

    test "includes customer information when requested" do
      # Arrange
      order = create_order(%{})

      query =
        GetOrderQuery.new(%{
          id: order.id,
          include_customer: true
        })

      # Act
      {:ok, retrieved_order} = OrderQueryHandler.handle(query)

      # Assert
      assert retrieved_order.customer != nil
      # Customer data would be populated from customer service
    end

    test "includes order timeline when requested" do
      # Arrange
      order = create_order(%{})

      query =
        GetOrderQuery.new(%{
          id: order.id,
          include_timeline: true
        })

      # Act
      {:ok, retrieved_order} = OrderQueryHandler.handle(query)

      # Assert
      assert retrieved_order.timeline != nil
      assert is_list(retrieved_order.timeline)

      assert Enum.all?(retrieved_order.timeline, fn event ->
               Map.has_key?(event, :timestamp) && Map.has_key?(event, :status)
             end)
    end
  end

  describe "handle ListOrdersQuery" do
    test "retrieves orders with pagination" do
      # Create some test orders
      for _ <- 1..15, do: create_order(%{})
      # Arrange
      query = ListOrdersQuery.new(%{page: 1, page_size: 10})

      # Act
      result = OrderQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: orders, metadata: metadata}} = result
      assert length(orders) <= 10
      assert metadata.page == 1
      assert metadata.page_size == 10
    end

    test "filters orders by date range" do
      # Arrange
      start_date = DateTime.utc_now() |> DateTime.add(-7, :day)
      end_date = DateTime.utc_now()

      query =
        ListOrdersQuery.new(%{
          start_date: start_date,
          end_date: end_date
        })

      # Act
      {:ok, %{data: orders}} = OrderQueryHandler.handle(query)

      # Assert
      assert Enum.all?(orders, fn order ->
               DateTime.compare(order.created_at, start_date) != :lt &&
                 DateTime.compare(order.created_at, end_date) != :gt
             end)
    end

    test "sorts orders by creation date descending by default" do
      # Arrange
      query = ListOrdersQuery.new(%{})

      # Act
      {:ok, %{data: orders}} = OrderQueryHandler.handle(query)

      # Assert
      dates = Enum.map(orders, & &1.created_at)
      assert dates == Enum.sort(dates, {:desc, DateTime})
    end

    test "filters by minimum order amount" do
      # Arrange
      min_amount = Decimal.new("100.00")
      query = ListOrdersQuery.new(%{min_amount: min_amount})

      # Act
      {:ok, %{data: orders}} = OrderQueryHandler.handle(query)

      # Assert
      assert Enum.all?(orders, fn order ->
               Decimal.compare(order.total_amount, min_amount) != :lt
             end)
    end
  end

  describe "handle GetOrdersByCustomerQuery" do
    test "retrieves all orders for a specific customer" do
      # Arrange
      customer_id = Ecto.UUID.generate()
      create_order(%{customer_id: customer_id, status: "completed"})
      create_order(%{customer_id: customer_id, status: "pending"})
      create_order(%{customer_id: Ecto.UUID.generate(), status: "pending"})

      query = GetOrdersByCustomerQuery.new(%{customer_id: customer_id})

      # Act
      result = OrderQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: orders}} = result
      assert length(orders) == 2
      assert Enum.all?(orders, &(&1.customer_id == customer_id))
    end

    @tag :skip
    test "includes order summary statistics" do
      # Arrange
      customer_id = Ecto.UUID.generate()

      create_order(%{
        customer_id: customer_id,
        total_amount: Decimal.new("50.00"),
        status: "completed"
      })

      create_order(%{
        customer_id: customer_id,
        total_amount: Decimal.new("75.00"),
        status: "completed"
      })

      query =
        GetOrdersByCustomerQuery.new(%{
          customer_id: customer_id,
          include_stats: true
        })

      # Act
      {:ok, result} = OrderQueryHandler.handle(query)

      # Assert
      assert result.stats.total_orders == 2
      assert Decimal.equal?(result.stats.total_spent, Decimal.new("125.00"))
      assert Decimal.equal?(result.stats.average_order_value, Decimal.new("62.50"))
    end

    @tag :skip
    test "filters customer orders by status" do
      # Arrange
      customer_id = Ecto.UUID.generate()
      create_order(%{customer_id: customer_id, status: "completed"})
      create_order(%{customer_id: customer_id, status: "pending"})
      create_order(%{customer_id: customer_id, status: "cancelled"})

      query =
        GetOrdersByCustomerQuery.new(%{
          customer_id: customer_id,
          status: "completed"
        })

      # Act
      {:ok, %{data: orders}} = OrderQueryHandler.handle(query)

      # Assert
      assert length(orders) == 1
      assert Atom.to_string(hd(orders).status) == "completed"
    end

    test "returns empty list for customer with no orders" do
      # Arrange
      query = GetOrdersByCustomerQuery.new(%{customer_id: Ecto.UUID.generate()})

      # Act
      result = OrderQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: []}} = result
    end
  end

  describe "handle GetOrdersByStatusQuery" do
    test "retrieves orders by single status" do
      # Arrange
      create_order(%{status: "pending"})
      create_order(%{status: "pending"})
      create_order(%{status: "completed"})

      query = GetOrdersByStatusQuery.new(%{status: "pending"})

      # Act
      {:ok, %{data: orders}} = OrderQueryHandler.handle(query)

      # Assert
      assert length(orders) == 2
      assert Enum.all?(orders, &(Atom.to_string(&1.status) == "pending"))
    end

    test "retrieves orders by multiple statuses" do
      # Arrange
      create_order(%{status: "pending"})
      create_order(%{status: "processing"})
      create_order(%{status: "completed"})
      create_order(%{status: "cancelled"})

      query =
        GetOrdersByStatusQuery.new(%{
          statuses: ["pending", "processing"]
        })

      # Act
      {:ok, %{data: orders}} = OrderQueryHandler.handle(query)

      # Assert
      assert length(orders) == 2
      assert Enum.all?(orders, &(Atom.to_string(&1.status) in ["pending", "processing"]))
    end

    test "includes status duration metrics" do
      # Arrange
      query =
        GetOrdersByStatusQuery.new(%{
          status: "processing",
          include_duration_metrics: true
        })

      # Act
      {:ok, result} = OrderQueryHandler.handle(query)

      # Assert
      assert result.metrics != nil
      assert Map.has_key?(result.metrics, :average_duration)
      assert Map.has_key?(result.metrics, :min_duration)
      assert Map.has_key?(result.metrics, :max_duration)
    end
  end

  describe "handle GetOrderStatsQuery" do
    @tag :skip
    test "calculates overall order statistics" do
      # Arrange
      create_order(%{total_amount: Decimal.new("100.00"), status: "completed"})
      create_order(%{total_amount: Decimal.new("200.00"), status: "completed"})
      create_order(%{total_amount: Decimal.new("150.00"), status: "pending"})

      query = GetOrderStatsQuery.new(%{})

      # Act
      result = OrderQueryHandler.handle(query)

      # Assert
      assert {:ok, stats} = result
      assert stats.total_orders == 3
      assert stats.completed_orders == 2
      assert Decimal.equal?(stats.total_revenue, Decimal.new("300.00"))
      assert stats.average_order_value == Decimal.new("150.00")
    end

    test "calculates statistics for specific time period" do
      # Arrange
      start_date = DateTime.utc_now() |> DateTime.add(-30, :day)
      end_date = DateTime.utc_now()

      query =
        GetOrderStatsQuery.new(%{
          start_date: start_date,
          end_date: end_date
        })

      # Act
      {:ok, stats} = OrderQueryHandler.handle(query)

      # Assert
      assert stats.period.start_date == start_date
      assert stats.period.end_date == end_date
    end

    test "groups statistics by time interval" do
      # Arrange
      query =
        GetOrderStatsQuery.new(%{
          group_by: "day",
          start_date: DateTime.utc_now() |> DateTime.add(-7, :day),
          end_date: DateTime.utc_now()
        })

      # Act
      {:ok, stats} = OrderQueryHandler.handle(query)

      # Assert
      assert is_list(stats.time_series)

      assert Enum.all?(stats.time_series, fn point ->
               Map.has_key?(point, :date) &&
                 Map.has_key?(point, :order_count) &&
                 Map.has_key?(point, :revenue)
             end)
    end

    test "includes product performance metrics" do
      # Arrange
      query =
        GetOrderStatsQuery.new(%{
          include_product_metrics: true
        })

      # Act
      {:ok, stats} = OrderQueryHandler.handle(query)

      # Assert
      assert stats.top_products != nil
      assert is_list(stats.top_products)

      assert Enum.all?(stats.top_products, fn product ->
               Map.has_key?(product, :product_id) &&
                 Map.has_key?(product, :quantity_sold) &&
                 Map.has_key?(product, :revenue)
             end)
    end

    test "calculates order status distribution" do
      # Arrange
      create_order(%{status: "pending"})
      create_order(%{status: "pending"})
      create_order(%{status: "processing"})
      create_order(%{status: "completed"})

      query = GetOrderStatsQuery.new(%{})

      # Act
      {:ok, stats} = OrderQueryHandler.handle(query)

      # Assert
      assert stats.status_distribution.pending == 2
      assert stats.status_distribution.processing == 1
      assert stats.status_distribution.completed == 1
    end
  end

  describe "complex queries" do
    test "handles orders with many items efficiently" do
      # Create order with many items
      items =
        for i <- 1..50 do
          %{
            id: Ecto.UUID.generate(),
            product_id: Ecto.UUID.generate(),
            product_name: "Product #{i}",
            quantity: 1,
            unit_price: Decimal.new("10.00"),
            total_price: Decimal.new("10.00")
          }
        end

      order = create_order(%{items: items})

      query = GetOrderQuery.new(%{id: order.id})
      {:ok, retrieved_order} = OrderQueryHandler.handle(query)

      assert length(retrieved_order.items) == 50
    end

    test "filters and sorts large result sets" do
      # Create many orders
      for i <- 1..100 do
        create_order(%{
          total_amount: Decimal.new(:rand.uniform(1000)),
          status: Enum.random(["pending", "processing", "completed"])
        })
      end

      query =
        ListOrdersQuery.new(%{
          min_amount: Decimal.new("500"),
          sort_by: "total_amount",
          sort_order: "desc",
          page_size: 20
        })

      {:ok, %{data: orders}} = OrderQueryHandler.handle(query)

      # Verify filtering and sorting
      assert length(orders) <= 20

      assert Enum.all?(orders, fn o ->
               Decimal.compare(o.total_amount, Decimal.new("500")) != :lt
             end)

      amounts = Enum.map(orders, & &1.total_amount)
      assert amounts == Enum.sort(amounts, {:desc, Decimal})
    end
  end

  # Helper functions

  defp create_order(attrs) do
    order_attrs = %{
      id: attrs[:id] || Ecto.UUID.generate(),
      customer_id: attrs[:customer_id] || Ecto.UUID.generate(),
      status: attrs[:status] || "pending",
      total_amount: attrs[:total_amount] || Decimal.new("99.99"),
      subtotal: attrs[:subtotal] || attrs[:total_amount] || Decimal.new("99.99"),
      tax_amount: attrs[:tax_amount] || Decimal.new("0"),
      shipping_cost: attrs[:shipping_cost] || Decimal.new("0"),
      items:
        attrs[:items] ||
          [
            %{
              product_id: Ecto.UUID.generate(),
              product_name: "Test Product",
              quantity: 1,
              unit_price: Decimal.new("99.99"),
              subtotal: Decimal.new("99.99")
            }
          ],
      shipping_address: attrs[:shipping_address],
      payment_status: attrs[:payment_status],
      saga_state: attrs[:saga_state]
    }

    {:ok, order} =
      QueryService.Infrastructure.Database.Schemas.OrderSchema
      |> struct(order_attrs)
      |> QueryService.Infrastructure.Database.Repo.insert()

    OrderRepository.find_by_id_uncached(order.id)
    |> case do
      {:ok, order} -> order
      _ -> raise "Failed to create order in test"
    end
  end
end
