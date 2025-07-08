defmodule CommandService.Application.Handlers.ProductCommandHandlerTest do
  use ExUnit.Case, async: true

  alias CommandService.Application.Handlers.ProductCommandHandler

  alias CommandService.Application.Commands.{
    CreateProductCommand,
    DeleteProductCommand,
    UpdateProductCommand
  }

  alias CommandService.Domain.Aggregates.Product
  alias CommandService.Infrastructure.Database.Repo
  alias CommandService.Infrastructure.EventStore.PostgresEventStore
  alias CommandService.Infrastructure.Repositories.ProductRepository
  alias Ecto.Adapters.SQL.Sandbox

  import ElixirCqrs.Factory
  import ElixirCqrs.TestHelpers
  import ElixirCqrs.EventStoreHelpers

  setup do
    # Setup test database connections
    :ok = Sandbox.checkout(Repo)

    # Optionally setup mocks if using Mox
    # Mox.stub_with(...)

    :ok
  end

  describe "handle CreateProductCommand" do
    test "successfully creates a product with valid data" do
      # Arrange
      product_attrs =
        build(:product, %{
          name: "Test Product",
          price: Decimal.new("99.99"),
          category_id: UUID.uuid4()
        })

      command =
        CreateProductCommand.new(%{
          name: product_attrs.name,
          description: product_attrs.description,
          price: product_attrs.price,
          category_id: product_attrs.category_id,
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      assert is_list(events)
      assert length(events) == 1

      [event] = events
      assert event.event_type == "product_created"
      assert event.aggregate_type == "product"
      assert event.event_data.name == "Test Product"
      assert Decimal.equal?(event.event_data.price, Decimal.new("99.99"))
    end

    test "fails to create product with invalid price" do
      # Arrange
      command =
        CreateProductCommand.new(%{
          name: "Invalid Product",
          description: "Test",
          price: Decimal.new("-10.00"),
          category_id: UUID.uuid4(),
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:error, :invalid_price} = result
    end

    test "fails to create product with empty name" do
      # Arrange
      command =
        CreateProductCommand.new(%{
          name: "",
          description: "Test",
          price: Decimal.new("10.00"),
          category_id: UUID.uuid4(),
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:error, :invalid_name} = result
    end

    test "fails to create product without category_id" do
      # Arrange
      command =
        CreateProductCommand.new(%{
          name: "Test Product",
          description: "Test",
          price: Decimal.new("10.00"),
          category_id: nil,
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:error, :missing_category} = result
    end
  end

  describe "handle UpdateProductCommand" do
    setup do
      # Create an existing product
      product = create_test_product()
      {:ok, product: product}
    end

    test "successfully updates product price", %{product: product} do
      # Arrange
      new_price = Decimal.new("149.99")

      command =
        UpdateProductCommand.new(%{
          id: product.id,
          price: new_price,
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      assert length(events) == 1

      [event] = events
      assert event.event_type == "product_updated"
      assert event.aggregate_id == product.id
      assert Decimal.equal?(event.event_data.price, new_price)
    end

    test "successfully updates product name and description", %{product: product} do
      # Arrange
      command =
        UpdateProductCommand.new(%{
          id: product.id,
          name: "Updated Product Name",
          description: "Updated description",
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      [event] = events
      assert event.event_data.name == "Updated Product Name"
      assert event.event_data.description == "Updated description"
    end

    test "fails to update product with invalid price", %{product: product} do
      # Arrange
      command =
        UpdateProductCommand.new(%{
          id: product.id,
          price: Decimal.new("0"),
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:error, :invalid_price} = result
    end

    test "fails to update non-existent product" do
      # Arrange
      command =
        UpdateProductCommand.new(%{
          id: UUID.uuid4(),
          name: "Updated Name",
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:error, :product_not_found} = result
    end

    test "maintains product version on update", %{product: product} do
      # First update
      command1 =
        UpdateProductCommand.new(%{
          id: product.id,
          name: "First Update",
          metadata: test_metadata()
        })

      {:ok, events1} = ProductCommandHandler.handle(command1)

      # Second update
      command2 =
        UpdateProductCommand.new(%{
          id: product.id,
          name: "Second Update",
          metadata: test_metadata()
        })

      {:ok, events2} = ProductCommandHandler.handle(command2)

      # Assert version increments
      assert hd(events1).event_version == 2
      assert hd(events2).event_version == 3
    end
  end

  describe "handle DeleteProductCommand" do
    setup do
      product = create_test_product()
      {:ok, product: product}
    end

    test "successfully deletes a product", %{product: product} do
      # Arrange
      command =
        DeleteProductCommand.new(%{
          id: product.id,
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      assert length(events) == 1

      [event] = events
      assert event.event_type == "product_deleted"
      assert event.aggregate_id == product.id
    end

    test "fails to delete non-existent product" do
      # Arrange
      command =
        DeleteProductCommand.new(%{
          id: UUID.uuid4(),
          metadata: test_metadata()
        })

      # Act
      result = ProductCommandHandler.handle(command)

      # Assert
      assert {:error, :product_not_found} = result
    end

    test "prevents operations on deleted product", %{product: product} do
      # Delete the product
      delete_command =
        DeleteProductCommand.new(%{
          id: product.id,
          metadata: test_metadata()
        })

      {:ok, _} = ProductCommandHandler.handle(delete_command)

      # Try to update deleted product
      update_command =
        UpdateProductCommand.new(%{
          id: product.id,
          name: "Should Fail",
          metadata: test_metadata()
        })

      result = ProductCommandHandler.handle(update_command)
      assert {:error, :product_deleted} = result
    end
  end

  describe "concurrent operations" do
    test "handles concurrent updates correctly" do
      product = create_test_product()

      # Simulate concurrent updates
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            command =
              UpdateProductCommand.new(%{
                id: product.id,
                name: "Concurrent Update #{i}",
                metadata: test_metadata()
              })

            ProductCommandHandler.handle(command)
          end)
        end

      # Wait for all tasks
      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      # Check final state
      events = get_aggregate_events(product.id)
      # 1 create + 5 updates
      assert length(events) == 6
    end
  end

  # Helper functions
  defp create_test_product do
    product_attrs = build(:product)
    command = CreateProductCommand.new(Map.merge(product_attrs, %{metadata: test_metadata()}))

    {:ok, events} = ProductCommandHandler.handle(command)
    event = hd(events)

    %Product{
      id: event.aggregate_id,
      name: event.event_data.name,
      description: event.event_data.description,
      price: event.event_data.price,
      category_id: event.event_data.category_id,
      version: 1
    }
  end
end
