defmodule CommandService.Application.Handlers.OrderCommandHandlerTest do
  use ExUnit.Case, async: true

  alias CommandService.Application.Handlers.OrderCommandHandler

  alias CommandService.Application.Commands.{
    CancelOrderCommand,
    CreateOrderCommand,
    UpdateOrderCommand
  }

  alias CommandService.Domain.Aggregates.Order
  alias CommandService.Infrastructure.Database.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias Shared.Infrastructure.Saga.OrderSaga

  # import ElixirCqrs.Factory
  # import ElixirCqrs.TestHelpers
  # import ElixirCqrs.EventStoreHelpers

  setup do
    :ok = Sandbox.checkout(Repo)
    :ok
  end

  describe "handle CreateOrderCommand" do
    test "successfully creates an order with valid items" do
      # Arrange
      order_items = [
        build(:order_item, %{
          product_id: UUID.uuid4(),
          product_name: "Product 1",
          quantity: 2,
          unit_price: Decimal.new("50.00")
        }),
        build(:order_item, %{
          product_id: UUID.uuid4(),
          product_name: "Product 2",
          quantity: 1,
          unit_price: Decimal.new("30.00")
        })
      ]

      command =
        CreateOrderCommand.new(%{
          customer_id: UUID.uuid4(),
          items: order_items,
          shipping_address: build(:shipping_address),
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      assert length(events) == 1

      [event] = events
      assert event.event_type == "order_created"
      assert event.aggregate_type == "order"
      assert event.event_data.customer_id == command.customer_id
      assert length(event.event_data.items) == 2
      assert event.event_data.status == "pending"

      # Check total calculation
      # (2 * 50) + (1 * 30)
      expected_total = Decimal.new("130.00")
      assert Decimal.equal?(event.event_data.total_amount, expected_total)
    end

    test "fails to create order without items" do
      # Arrange
      command =
        CreateOrderCommand.new(%{
          customer_id: UUID.uuid4(),
          items: [],
          shipping_address: build(:shipping_address),
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :no_items} = result
    end

    test "fails to create order with invalid quantity" do
      # Arrange
      order_items = [
        build(:order_item, %{quantity: 0})
      ]

      command =
        CreateOrderCommand.new(%{
          customer_id: UUID.uuid4(),
          items: order_items,
          shipping_address: build(:shipping_address),
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :invalid_quantity} = result
    end

    test "fails to create order without customer_id" do
      # Arrange
      command =
        CreateOrderCommand.new(%{
          customer_id: nil,
          items: [build(:order_item)],
          shipping_address: build(:shipping_address),
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :missing_customer} = result
    end

    test "fails to create order without shipping address" do
      # Arrange
      command =
        CreateOrderCommand.new(%{
          customer_id: UUID.uuid4(),
          items: [build(:order_item)],
          shipping_address: nil,
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :missing_shipping_address} = result
    end

    test "triggers order saga on creation" do
      # Arrange
      command =
        CreateOrderCommand.new(%{
          customer_id: UUID.uuid4(),
          items: [build(:order_item)],
          shipping_address: build(:shipping_address),
          metadata: test_metadata()
        })

      # Act
      {:ok, events} = OrderCommandHandler.handle(command)
      [event] = events

      # Assert saga trigger
      assert event.event_metadata[:saga_trigger] == true
      assert event.event_metadata[:saga_type] == OrderSaga
    end
  end

  describe "handle UpdateOrderCommand" do
    setup do
      order = create_test_order()
      {:ok, order: order}
    end

    test "successfully updates order status", %{order: order} do
      # Arrange
      command =
        UpdateOrderCommand.new(%{
          id: order.id,
          status: "processing",
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      [event] = events
      assert event.event_type == "order_updated"
      assert event.event_data.status == "processing"
    end

    test "successfully updates shipping address before processing", %{order: order} do
      # Arrange
      new_address =
        build(:shipping_address, %{
          street: "123 New Street",
          city: "New City"
        })

      command =
        UpdateOrderCommand.new(%{
          id: order.id,
          shipping_address: new_address,
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      [event] = events
      assert event.event_data.shipping_address.street == "123 New Street"
    end

    test "fails to update order in final status", %{order: order} do
      # First, move order to completed status
      complete_command =
        UpdateOrderCommand.new(%{
          id: order.id,
          status: "completed",
          metadata: test_metadata()
        })

      {:ok, _} = OrderCommandHandler.handle(complete_command)

      # Try to update completed order
      command =
        UpdateOrderCommand.new(%{
          id: order.id,
          status: "processing",
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :order_completed} = result
    end

    test "validates status transitions", %{order: order} do
      # Invalid transition: pending -> completed (skipping processing)
      command =
        UpdateOrderCommand.new(%{
          id: order.id,
          status: "completed",
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :invalid_status_transition} = result
    end

    test "fails to update non-existent order" do
      # Arrange
      command =
        UpdateOrderCommand.new(%{
          id: UUID.uuid4(),
          status: "processing",
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :order_not_found} = result
    end
  end

  describe "handle CancelOrderCommand" do
    setup do
      order = create_test_order()
      {:ok, order: order}
    end

    test "successfully cancels a pending order", %{order: order} do
      # Arrange
      command =
        CancelOrderCommand.new(%{
          id: order.id,
          reason: "Customer requested cancellation",
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      [event] = events
      assert event.event_type == "order_cancelled"
      assert event.event_data.reason == "Customer requested cancellation"
      assert event.event_data.status == "cancelled"
    end

    test "triggers compensation saga on cancellation", %{order: order} do
      # Arrange
      command =
        CancelOrderCommand.new(%{
          id: order.id,
          reason: "Out of stock",
          metadata: test_metadata()
        })

      # Act
      {:ok, events} = OrderCommandHandler.handle(command)
      [event] = events

      # Assert compensation trigger
      assert event.event_metadata[:trigger_compensation] == true
    end

    test "fails to cancel completed order", %{order: order} do
      # Complete the order first
      complete_command =
        UpdateOrderCommand.new(%{
          id: order.id,
          status: "completed",
          metadata: test_metadata()
        })

      {:ok, _} = OrderCommandHandler.handle(complete_command)

      # Try to cancel
      command =
        CancelOrderCommand.new(%{
          id: order.id,
          reason: "Too late",
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :cannot_cancel_completed_order} = result
    end

    test "fails to cancel already cancelled order", %{order: order} do
      # Cancel once
      cancel_command =
        CancelOrderCommand.new(%{
          id: order.id,
          reason: "First cancellation",
          metadata: test_metadata()
        })

      {:ok, _} = OrderCommandHandler.handle(cancel_command)

      # Try to cancel again
      command =
        CancelOrderCommand.new(%{
          id: order.id,
          reason: "Second cancellation",
          metadata: test_metadata()
        })

      # Act
      result = OrderCommandHandler.handle(command)

      # Assert
      assert {:error, :order_already_cancelled} = result
    end
  end

  describe "order calculations" do
    test "correctly calculates order totals with multiple items" do
      # Arrange
      items = [
        build(:order_item, %{quantity: 3, unit_price: Decimal.new("25.50")}),
        build(:order_item, %{quantity: 2, unit_price: Decimal.new("10.00")}),
        build(:order_item, %{quantity: 1, unit_price: Decimal.new("100.00")})
      ]

      command =
        CreateOrderCommand.new(%{
          customer_id: UUID.uuid4(),
          items: items,
          shipping_address: build(:shipping_address),
          metadata: test_metadata()
        })

      # Act
      {:ok, events} = OrderCommandHandler.handle(command)
      [event] = events

      # Assert
      # (3*25.50) + (2*10) + (1*100)
      expected_total = Decimal.new("196.50")
      assert Decimal.equal?(event.event_data.total_amount, expected_total)
    end

    test "handles decimal precision correctly" do
      # Arrange with prices that could cause precision issues
      items = [
        build(:order_item, %{quantity: 1, unit_price: Decimal.new("0.01")}),
        build(:order_item, %{quantity: 1, unit_price: Decimal.new("0.02")}),
        build(:order_item, %{quantity: 1, unit_price: Decimal.new("0.03")})
      ]

      command =
        CreateOrderCommand.new(%{
          customer_id: UUID.uuid4(),
          items: items,
          shipping_address: build(:shipping_address),
          metadata: test_metadata()
        })

      # Act
      {:ok, events} = OrderCommandHandler.handle(command)
      [event] = events

      # Assert
      expected_total = Decimal.new("0.06")
      assert Decimal.equal?(event.event_data.total_amount, expected_total)
    end
  end

  # Helper functions
  defp create_test_order(attrs \\ %{}) do
    order_attrs = build(:order, attrs)
    command = CreateOrderCommand.new(Map.merge(order_attrs, %{metadata: test_metadata()}))

    {:ok, events} = OrderCommandHandler.handle(command)
    event = hd(events)

    %Order{
      id: event.aggregate_id,
      customer_id: event.event_data.customer_id,
      items: event.event_data.items,
      total_amount: event.event_data.total_amount,
      status: event.event_data.status,
      shipping_address: event.event_data.shipping_address,
      version: 1
    }
  end
end
