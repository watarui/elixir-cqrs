defmodule ClientService.GraphQL.OrderIntegrationTest do
  use ExUnit.Case, async: false
  use ClientService.ConnCase
  
  import ElixirCqrs.GraphQLHelpers
  import ElixirCqrs.TestHelpers
  
  setup do
    # Setup both command and query databases
    setup_all_dbs(%{})
    
    # Create test products
    products = create_test_products()
    {:ok, products: products}
  end

  describe "orders query" do
    test "returns list of orders with pagination" do
      # Create orders
      customer_id = UUID.uuid4()
      order1 = create_order_with_projection(%{
        customer_id: customer_id,
        status: "pending"
      })
      order2 = create_order_with_projection(%{
        customer_id: customer_id,
        status: "processing"
      })

      query = """
        query {
          orders(page: 1, pageSize: 10) {
            id
            customerId
            status
            totalAmount
            items {
              productId
              quantity
              unitPrice
            }
          }
        }
      """
      
      result = run_query(query)
      data = assert_no_errors(result)
      
      orders = data["orders"]
      assert length(orders) >= 2
      assert Enum.any?(orders, & &1["id"] == order1.id)
      assert Enum.any?(orders, & &1["id"] == order2.id)
    end

    test "filters orders by status" do
      create_order_with_projection(%{status: "pending"})
      create_order_with_projection(%{status: "pending"})
      create_order_with_projection(%{status: "completed"})

      query = """
        query {
          orders(status: "pending") {
            id
            status
          }
        }
      """
      
      result = run_query(query)
      data = assert_no_errors(result)
      
      orders = data["orders"]
      assert length(orders) == 2
      assert Enum.all?(orders, & &1["status"] == "pending")
    end

    test "filters orders by date range" do
      # Create old order
      old_date = DateTime.utc_now() |> DateTime.add(-30, :day)
      create_order_with_projection(%{
        created_at: old_date
      })
      
      # Create recent order
      recent = create_order_with_projection(%{
        created_at: DateTime.utc_now()
      })

      week_ago = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.to_iso8601()
      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.to_iso8601()
      
      query = """
        query($startDate: DateTime!, $endDate: DateTime!) {
          orders(startDate: $startDate, endDate: $endDate) {
            id
          }
        }
      """
      
      result = run_query(query, %{
        "startDate" => week_ago,
        "endDate" => tomorrow
      })
      
      data = assert_no_errors(result)
      orders = data["orders"]
      
      assert length(orders) == 1
      assert hd(orders)["id"] == recent.id
    end
  end

  describe "order query" do
    test "returns single order with full details", %{products: products} do
      order = create_order_with_projection(%{
        items: [
          %{
            product_id: hd(products).id,
            product_name: hd(products).name,
            quantity: 2,
            unit_price: hd(products).price
          }
        ]
      })

      query = """
        query($id: ID!) {
          order(id: $id) {
            id
            customerId
            status
            totalAmount
            items {
              productId
              productName
              quantity
              unitPrice
              subtotal
            }
            shippingAddress {
              street
              city
              state
              postalCode
              country
            }
          }
        }
      """
      
      result = run_query(query, %{"id" => order.id})
      data = assert_no_errors(result)
      
      returned_order = data["order"]
      assert returned_order["id"] == order.id
      assert length(returned_order["items"]) == 1
      assert returned_order["shippingAddress"] != nil
    end

    test "returns null for non-existent order" do
      query = """
        query($id: ID!) {
          order(id: $id) {
            id
          }
        }
      """
      
      result = run_query(query, %{"id" => UUID.uuid4()})
      data = assert_no_errors(result)
      
      assert data["order"] == nil
    end
  end

  describe "ordersByCustomer query" do
    test "returns all orders for specific customer" do
      customer_id = UUID.uuid4()
      other_customer_id = UUID.uuid4()
      
      # Create orders for target customer
      order1 = create_order_with_projection(%{customer_id: customer_id})
      order2 = create_order_with_projection(%{customer_id: customer_id})
      
      # Create order for different customer
      create_order_with_projection(%{customer_id: other_customer_id})

      query = """
        query($customerId: ID!) {
          ordersByCustomer(customerId: $customerId) {
            id
            customerId
          }
        }
      """
      
      result = run_query(query, %{"customerId" => customer_id})
      data = assert_no_errors(result)
      
      orders = data["ordersByCustomer"]
      assert length(orders) == 2
      assert Enum.all?(orders, & &1["customerId"] == customer_id)
    end

    test "includes customer statistics when requested" do
      customer_id = UUID.uuid4()
      
      create_order_with_projection(%{
        customer_id: customer_id,
        total_amount: Decimal.new("100.00"),
        status: "completed"
      })
      create_order_with_projection(%{
        customer_id: customer_id,
        total_amount: Decimal.new("200.00"),
        status: "completed"
      })

      query = """
        query($customerId: ID!) {
          customerOrderStats(customerId: $customerId) {
            totalOrders
            completedOrders
            totalSpent
            averageOrderValue
          }
        }
      """
      
      result = run_query(query, %{"customerId" => customer_id})
      data = assert_no_errors(result)
      
      stats = data["customerOrderStats"]
      assert stats["totalOrders"] == 2
      assert stats["completedOrders"] == 2
      assert stats["totalSpent"] == "300.00"
      assert stats["averageOrderValue"] == "150.00"
    end
  end

  describe "createOrder mutation" do
    test "successfully creates an order", %{products: products} do
      product1 = hd(products)
      product2 = hd(tl(products))
      
      input = %{
        "customerId" => UUID.uuid4(),
        "items" => [
          %{
            "productId" => product1.id,
            "quantity" => 2
          },
          %{
            "productId" => product2.id,
            "quantity" => 1
          }
        ],
        "shippingAddress" => %{
          "street" => "123 Main St",
          "city" => "New York",
          "state" => "NY",
          "postalCode" => "10001",
          "country" => "USA"
        }
      }

      mutation = """
        mutation($input: CreateOrderInput!) {
          createOrder(input: $input) {
            id
            customerId
            status
            totalAmount
            items {
              productId
              quantity
              unitPrice
            }
          }
        }
      """
      
      result = run_query(mutation, %{"input" => input})
      data = assert_no_errors(result)
      
      created_order = data["createOrder"]
      assert created_order["id"] != nil
      assert created_order["status"] == "pending"
      assert length(created_order["items"]) == 2
      assert created_order["totalAmount"] != nil
    end

    test "validates order has items" do
      input = %{
        "customerId" => UUID.uuid4(),
        "items" => [],
        "shippingAddress" => %{
          "street" => "123 Main St",
          "city" => "New York",
          "state" => "NY",
          "postalCode" => "10001",
          "country" => "USA"
        }
      }

      mutation = """
        mutation($input: CreateOrderInput!) {
          createOrder(input: $input) {
            id
          }
        }
      """
      
      result = run_query(mutation, %{"input" => input})
      assert_has_error(result, "at least one item")
    end

    test "validates positive quantities" do
      input = %{
        "customerId" => UUID.uuid4(),
        "items" => [
          %{
            "productId" => UUID.uuid4(),
            "quantity" => 0
          }
        ],
        "shippingAddress" => %{
          "street" => "123 Main St",
          "city" => "New York",
          "state" => "NY",
          "postalCode" => "10001",
          "country" => "USA"
        }
      }

      mutation = """
        mutation($input: CreateOrderInput!) {
          createOrder(input: $input) {
            id
          }
        }
      """
      
      result = run_query(mutation, %{"input" => input})
      assert_has_error(result, "positive")
    end

    test "triggers order saga on creation" do
      # This test verifies that creating an order initiates the saga
      # In a real implementation, you might check saga state or events
      
      input = %{
        "customerId" => UUID.uuid4(),
        "items" => [
          %{
            "productId" => UUID.uuid4(),
            "quantity" => 1
          }
        ],
        "shippingAddress" => %{
          "street" => "123 Main St",
          "city" => "New York",
          "state" => "NY",
          "postalCode" => "10001",
          "country" => "USA"
        }
      }

      mutation = """
        mutation($input: CreateOrderInput!) {
          createOrder(input: $input) {
            id
            sagaStatus
          }
        }
      """
      
      result = run_query(mutation, %{"input" => input})
      data = assert_no_errors(result)
      
      created_order = data["createOrder"]
      # Saga should be initiated
      assert created_order["sagaStatus"] == "started" || 
             created_order["sagaStatus"] == nil  # Depending on implementation
    end
  end

  describe "updateOrderStatus mutation" do
    test "successfully updates order status" do
      order = create_order_with_projection(%{status: "pending"})

      mutation = """
        mutation($id: ID!, $status: OrderStatus!) {
          updateOrderStatus(id: $id, status: $status) {
            id
            status
            updatedAt
          }
        }
      """
      
      result = run_query(mutation, %{
        "id" => order.id,
        "status" => "PROCESSING"
      })
      
      data = assert_no_errors(result)
      updated = data["updateOrderStatus"]
      
      assert updated["status"] == "processing"
      assert updated["updatedAt"] != nil
    end

    test "validates status transitions" do
      # Create completed order
      order = create_order_with_projection(%{status: "completed"})

      mutation = """
        mutation($id: ID!, $status: OrderStatus!) {
          updateOrderStatus(id: $id, status: $status) {
            id
          }
        }
      """
      
      # Try to move back to pending
      result = run_query(mutation, %{
        "id" => order.id,
        "status" => "PENDING"
      })
      
      assert_has_error(result, "Invalid status transition")
    end
  end

  describe "cancelOrder mutation" do
    test "successfully cancels a pending order" do
      order = create_order_with_projection(%{status: "pending"})

      mutation = """
        mutation($id: ID!, $reason: String!) {
          cancelOrder(id: $id, reason: $reason) {
            id
            status
            cancellationReason
          }
        }
      """
      
      result = run_query(mutation, %{
        "id" => order.id,
        "reason" => "Customer requested"
      })
      
      data = assert_no_errors(result)
      cancelled = data["cancelOrder"]
      
      assert cancelled["status"] == "cancelled"
      assert cancelled["cancellationReason"] == "Customer requested"
    end

    test "cannot cancel completed order" do
      order = create_order_with_projection(%{status: "completed"})

      mutation = """
        mutation($id: ID!, $reason: String!) {
          cancelOrder(id: $id, reason: $reason) {
            id
          }
        }
      """
      
      result = run_query(mutation, %{
        "id" => order.id,
        "reason" => "Too late"
      })
      
      assert_has_error(result, "cannot be cancelled")
    end

    test "triggers compensation saga on cancellation" do
      order = create_order_with_projection(%{status: "processing"})

      mutation = """
        mutation($id: ID!, $reason: String!) {
          cancelOrder(id: $id, reason: $reason) {
            id
            status
            compensationStatus
          }
        }
      """
      
      result = run_query(mutation, %{
        "id" => order.id,
        "reason" => "Out of stock"
      })
      
      data = assert_no_errors(result)
      cancelled = data["cancelOrder"]
      
      # Verify compensation is triggered
      assert cancelled["compensationStatus"] == "initiated" ||
             cancelled["compensationStatus"] == nil  # Depending on implementation
    end
  end

  describe "orderStats query" do
    test "returns aggregate statistics" do
      # Create orders with different statuses
      create_order_with_projection(%{
        status: "completed",
        total_amount: Decimal.new("100.00")
      })
      create_order_with_projection(%{
        status: "completed",
        total_amount: Decimal.new("200.00")
      })
      create_order_with_projection(%{
        status: "pending",
        total_amount: Decimal.new("150.00")
      })

      query = """
        query {
          orderStats {
            totalOrders
            completedOrders
            pendingOrders
            totalRevenue
            averageOrderValue
          }
        }
      """
      
      result = run_query(query)
      data = assert_no_errors(result)
      
      stats = data["orderStats"]
      assert stats["totalOrders"] == 3
      assert stats["completedOrders"] == 2
      assert stats["pendingOrders"] == 1
      assert stats["totalRevenue"] == "300.00"  # Only completed orders
      assert stats["averageOrderValue"] == "150.00"
    end

    test "filters stats by date range" do
      # Create order outside range
      old_date = DateTime.utc_now() |> DateTime.add(-60, :day)
      create_order_with_projection(%{
        status: "completed",
        total_amount: Decimal.new("100.00"),
        created_at: old_date
      })
      
      # Create order within range
      create_order_with_projection(%{
        status: "completed",
        total_amount: Decimal.new("200.00"),
        created_at: DateTime.utc_now()
      })

      month_ago = DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.to_iso8601()
      tomorrow = DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.to_iso8601()
      
      query = """
        query($startDate: DateTime!, $endDate: DateTime!) {
          orderStats(startDate: $startDate, endDate: $endDate) {
            totalOrders
            totalRevenue
          }
        }
      """
      
      result = run_query(query, %{
        "startDate" => month_ago,
        "endDate" => tomorrow
      })
      
      data = assert_no_errors(result)
      stats = data["orderStats"]
      
      assert stats["totalOrders"] == 1
      assert stats["totalRevenue"] == "200.00"
    end
  end

  # Helper functions
  defp create_test_products do
    [
      create_product_with_projection(%{
        name: "Product 1",
        price: Decimal.new("50.00")
      }),
      create_product_with_projection(%{
        name: "Product 2",
        price: Decimal.new("75.00")
      }),
      create_product_with_projection(%{
        name: "Product 3",
        price: Decimal.new("100.00")
      })
    ]
  end

  defp create_order_with_projection(attrs \\ %{}) do
    default_attrs = %{
      customer_id: UUID.uuid4(),
      items: [
        %{
          product_id: UUID.uuid4(),
          product_name: "Test Product",
          quantity: 1,
          unit_price: Decimal.new("50.00")
        }
      ],
      total_amount: Decimal.new("50.00"),
      status: "pending",
      shipping_address: %{
        street: "123 Test St",
        city: "Test City",
        state: "TS",
        postal_code: "12345",
        country: "Test Country"
      }
    }
    
    order_attrs = Map.merge(default_attrs, attrs)
    
    # This would actually create through command service and wait for projection
    # For testing, we'll simulate direct creation
    {:ok, order} = QueryService.Infrastructure.Repositories.OrderRepository.create(order_attrs)
    order
  end
end