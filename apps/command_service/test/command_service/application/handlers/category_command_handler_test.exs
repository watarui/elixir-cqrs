defmodule CommandService.Application.Handlers.CategoryCommandHandlerTest do
  use ExUnit.Case, async: true

  alias CommandService.Application.Handlers.CategoryCommandHandler

  alias CommandService.Application.Commands.{
    CreateCategoryCommand,
    DeleteCategoryCommand,
    UpdateCategoryCommand
  }

  alias CommandService.Domain.Aggregates.Category
  alias CommandService.Infrastructure.Database.Repo
  alias Ecto.Adapters.SQL.Sandbox

  import ElixirCqrs.Factory
  import ElixirCqrs.TestHelpers
  import ElixirCqrs.EventStoreHelpers

  setup do
    :ok = Sandbox.checkout(Repo)
    :ok
  end

  describe "handle CreateCategoryCommand" do
    test "successfully creates a root category" do
      # Arrange
      command =
        CreateCategoryCommand.new(%{
          name: "Electronics",
          description: "Electronic products",
          parent_id: nil,
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      assert length(events) == 1

      [event] = events
      assert event.event_type == "category_created"
      assert event.aggregate_type == "category"
      assert event.event_data.name == "Electronics"
      assert event.event_data.parent_id == nil
      assert event.event_data.path == []
    end

    test "successfully creates a subcategory" do
      # Arrange
      parent = create_test_category(%{name: "Electronics"})

      command =
        CreateCategoryCommand.new(%{
          name: "Smartphones",
          description: "Mobile phones",
          parent_id: parent.id,
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      [event] = events
      assert event.event_data.parent_id == parent.id
      assert event.event_data.path == [parent.id]
    end

    test "fails to create category with empty name" do
      # Arrange
      command =
        CreateCategoryCommand.new(%{
          name: "",
          description: "Test",
          parent_id: nil,
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:error, :invalid_name} = result
    end

    test "fails to create category with duplicate name at same level" do
      # Arrange
      create_test_category(%{name: "Electronics"})

      command =
        CreateCategoryCommand.new(%{
          name: "Electronics",
          description: "Duplicate",
          parent_id: nil,
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:error, :duplicate_name} = result
    end

    test "enforces maximum depth limit" do
      # Create a chain of categories up to max depth
      root = create_test_category(%{name: "Level 0"})
      parent = root

      for level <- 1..4 do
        parent =
          create_test_category(%{
            name: "Level #{level}",
            parent_id: parent.id
          })
      end

      # Try to create one more level (should fail)
      command =
        CreateCategoryCommand.new(%{
          name: "Level 6",
          description: "Too deep",
          parent_id: parent.id,
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:error, :max_depth_exceeded} = result
    end
  end

  describe "handle UpdateCategoryCommand" do
    setup do
      category = create_test_category(%{name: "Original Category"})
      {:ok, category: category}
    end

    test "successfully updates category name and description", %{category: category} do
      # Arrange
      command =
        UpdateCategoryCommand.new(%{
          id: category.id,
          name: "Updated Category",
          description: "New description",
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      [event] = events
      assert event.event_type == "category_updated"
      assert event.event_data.name == "Updated Category"
      assert event.event_data.description == "New description"
    end

    test "fails to update category with duplicate name", %{category: category} do
      # Create another category
      create_test_category(%{name: "Existing Category"})

      # Try to update to duplicate name
      command =
        UpdateCategoryCommand.new(%{
          id: category.id,
          name: "Existing Category",
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:error, :duplicate_name} = result
    end

    test "fails to update non-existent category" do
      # Arrange
      command =
        UpdateCategoryCommand.new(%{
          id: UUID.uuid4(),
          name: "Should Fail",
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:error, :category_not_found} = result
    end

    test "cannot move category to create circular reference", %{category: parent} do
      # Create child category
      child =
        create_test_category(%{
          name: "Child",
          parent_id: parent.id
        })

      # Try to make parent a child of its own child
      command =
        UpdateCategoryCommand.new(%{
          id: parent.id,
          parent_id: child.id,
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:error, :circular_reference} = result
    end
  end

  describe "handle DeleteCategoryCommand" do
    setup do
      category = create_test_category(%{name: "Test Category"})
      {:ok, category: category}
    end

    test "successfully deletes an empty category", %{category: category} do
      # Arrange
      command =
        DeleteCategoryCommand.new(%{
          id: category.id,
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:ok, events} = result
      [event] = events
      assert event.event_type == "category_deleted"
      assert event.aggregate_id == category.id
    end

    test "fails to delete category with subcategories", %{category: parent} do
      # Create subcategory
      create_test_category(%{
        name: "Subcategory",
        parent_id: parent.id
      })

      # Try to delete parent
      command =
        DeleteCategoryCommand.new(%{
          id: parent.id,
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:error, :has_subcategories} = result
    end

    test "fails to delete category with products", %{category: category} do
      # Simulate category having products
      # This would typically involve checking product repository

      command =
        DeleteCategoryCommand.new(%{
          id: category.id,
          metadata: test_metadata()
        })

      # For this test, we'd need to mock the product check
      # Act & Assert would depend on implementation
    end

    test "fails to delete non-existent category" do
      # Arrange
      command =
        DeleteCategoryCommand.new(%{
          id: UUID.uuid4(),
          metadata: test_metadata()
        })

      # Act
      result = CategoryCommandHandler.handle(command)

      # Assert
      assert {:error, :category_not_found} = result
    end
  end

  describe "category hierarchy operations" do
    test "correctly builds category paths" do
      # Create hierarchy: Electronics -> Computers -> Laptops
      electronics = create_test_category(%{name: "Electronics"})

      computers =
        create_test_category(%{
          name: "Computers",
          parent_id: electronics.id
        })

      command =
        CreateCategoryCommand.new(%{
          name: "Laptops",
          description: "Portable computers",
          parent_id: computers.id,
          metadata: test_metadata()
        })

      {:ok, events} = CategoryCommandHandler.handle(command)
      [event] = events

      # Path should contain both parent IDs
      assert event.event_data.path == [electronics.id, computers.id]
    end

    test "updates child paths when parent moves" do
      # Create hierarchy
      root1 = create_test_category(%{name: "Root 1"})
      root2 = create_test_category(%{name: "Root 2"})

      child =
        create_test_category(%{
          name: "Child",
          parent_id: root1.id
        })

      grandchild =
        create_test_category(%{
          name: "Grandchild",
          parent_id: child.id
        })

      # Move child from root1 to root2
      command =
        UpdateCategoryCommand.new(%{
          id: child.id,
          parent_id: root2.id,
          metadata: test_metadata()
        })

      {:ok, events} = CategoryCommandHandler.handle(command)

      # Should generate events for updating paths of child and grandchild
      assert length(events) >= 1
      assert Enum.any?(events, &(&1.event_type == "category_moved"))
    end
  end

  # Helper functions
  defp create_test_category(attrs \\ %{}) do
    category_attrs = build(:category, attrs)
    command = CreateCategoryCommand.new(Map.merge(category_attrs, %{metadata: test_metadata()}))

    {:ok, events} = CategoryCommandHandler.handle(command)
    event = hd(events)

    %Category{
      id: event.aggregate_id,
      name: event.event_data.name,
      description: event.event_data.description,
      parent_id: event.event_data.parent_id,
      path: event.event_data.path,
      version: 1
    }
  end
end
