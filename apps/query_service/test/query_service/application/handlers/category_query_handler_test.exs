defmodule QueryService.Application.Handlers.CategoryQueryHandlerTest do
  use ExUnit.Case, async: true

  alias QueryService.Application.Handlers.CategoryQueryHandler

  alias QueryService.Application.Queries.{
    GetCategoryPathQuery,
    GetCategoryQuery,
    GetCategoryTreeQuery,
    ListCategoriesQuery
  }

  alias QueryService.Domain.ReadModels.Category
  alias QueryService.Infrastructure.Repositories.CategoryRepository

  import ElixirCqrs.Factory
  import ElixirCqrs.TestHelpers

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(QueryService.Infrastructure.Database.Repo)

    # Create test category hierarchy
    categories = create_test_categories()
    {:ok, categories: categories}
  end

  describe "handle GetCategoryQuery" do
    test "successfully retrieves an existing category", %{categories: categories} do
      # Arrange
      category = categories.electronics
      query = GetCategoryQuery.new(%{id: category.id})

      # Act
      result = CategoryQueryHandler.handle(query)

      # Assert
      assert {:ok, retrieved_category} = result
      assert retrieved_category.id == category.id
      assert retrieved_category.name == category.name
    end

    test "returns error for non-existent category" do
      # Arrange
      query = GetCategoryQuery.new(%{id: UUID.uuid4()})

      # Act
      result = CategoryQueryHandler.handle(query)

      # Assert
      assert {:error, :not_found} = result
    end

    test "includes parent category information", %{categories: categories} do
      # Arrange
      subcategory = categories.smartphones
      query = GetCategoryQuery.new(%{id: subcategory.id})

      # Act
      {:ok, category} = CategoryQueryHandler.handle(query)

      # Assert
      assert category.parent != nil
      assert category.parent.id == categories.electronics.id
    end

    test "includes child categories when requested", %{categories: categories} do
      # Arrange
      query =
        GetCategoryQuery.new(%{
          id: categories.electronics.id,
          include_children: true
        })

      # Act
      {:ok, category} = CategoryQueryHandler.handle(query)

      # Assert
      assert length(category.children) > 0
      assert Enum.any?(category.children, &(&1.id == categories.smartphones.id))
    end

    test "includes product count when requested", %{categories: categories} do
      # Arrange
      # Create some products in the category
      category_id = categories.electronics.id
      create_product(%{category_id: category_id})
      create_product(%{category_id: category_id})

      query =
        GetCategoryQuery.new(%{
          id: category_id,
          include_product_count: true
        })

      # Act
      {:ok, category} = CategoryQueryHandler.handle(query)

      # Assert
      assert category.product_count == 2
    end
  end

  describe "handle ListCategoriesQuery" do
    test "retrieves all root categories by default", %{categories: _} do
      # Arrange
      query = ListCategoriesQuery.new(%{})

      # Act
      result = CategoryQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: categories}} = result
      assert Enum.all?(categories, &(&1.parent_id == nil))
    end

    test "retrieves categories at specific level" do
      # Arrange
      query = ListCategoriesQuery.new(%{level: 1})

      # Act
      {:ok, %{data: categories}} = CategoryQueryHandler.handle(query)

      # Assert
      assert Enum.all?(categories, fn cat ->
               cat.parent_id != nil && length(cat.path) == 1
             end)
    end

    test "filters by parent category" do
      # Arrange
      parent_id = UUID.uuid4()
      create_category(%{name: "Child 1", parent_id: parent_id})
      create_category(%{name: "Child 2", parent_id: parent_id})
      create_category(%{name: "Other", parent_id: UUID.uuid4()})

      query = ListCategoriesQuery.new(%{parent_id: parent_id})

      # Act
      {:ok, %{data: categories}} = CategoryQueryHandler.handle(query)

      # Assert
      assert length(categories) == 2
      assert Enum.all?(categories, &(&1.parent_id == parent_id))
    end

    test "sorts categories alphabetically" do
      # Arrange
      query = ListCategoriesQuery.new(%{sort_by: "name"})

      # Act
      {:ok, %{data: categories}} = CategoryQueryHandler.handle(query)

      # Assert
      names = Enum.map(categories, & &1.name)
      assert names == Enum.sort(names)
    end

    test "includes nested children when requested" do
      # Arrange
      query =
        ListCategoriesQuery.new(%{
          include_children: true,
          max_depth: 2
        })

      # Act
      {:ok, %{data: categories}} = CategoryQueryHandler.handle(query)

      # Assert
      assert Enum.any?(categories, fn cat ->
               cat.children != [] &&
                 Enum.any?(cat.children, &(&1.children != []))
             end)
    end
  end

  describe "handle GetCategoryTreeQuery" do
    test "builds complete category tree from root", %{categories: categories} do
      # Arrange
      query = GetCategoryTreeQuery.new(%{})

      # Act
      result = CategoryQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: tree}} = result
      assert is_list(tree)

      # Find electronics in tree
      electronics = Enum.find(tree, &(&1.name == "Electronics"))
      assert electronics != nil
      assert length(electronics.children) > 0
    end

    test "builds subtree from specific category", %{categories: categories} do
      # Arrange
      query =
        GetCategoryTreeQuery.new(%{
          root_id: categories.electronics.id
        })

      # Act
      {:ok, %{data: tree}} = CategoryQueryHandler.handle(query)

      # Assert
      assert length(tree) == 1
      root = hd(tree)
      assert root.id == categories.electronics.id
      assert length(root.children) > 0
    end

    test "limits tree depth", %{categories: _} do
      # Arrange
      query = GetCategoryTreeQuery.new(%{max_depth: 1})

      # Act
      {:ok, %{data: tree}} = CategoryQueryHandler.handle(query)

      # Assert - no grandchildren should be loaded
      assert Enum.all?(tree, fn cat ->
               Enum.all?(cat.children, &(&1.children == []))
             end)
    end

    test "includes metadata in tree nodes", %{categories: categories} do
      # Arrange
      # Add products to categories
      create_product(%{category_id: categories.smartphones.id})
      create_product(%{category_id: categories.smartphones.id})

      query =
        GetCategoryTreeQuery.new(%{
          include_metadata: true
        })

      # Act
      {:ok, %{data: tree}} = CategoryQueryHandler.handle(query)

      # Assert
      electronics = Enum.find(tree, &(&1.name == "Electronics"))
      smartphones = Enum.find(electronics.children, &(&1.name == "Smartphones"))

      assert smartphones.metadata.product_count == 2
      assert smartphones.metadata.total_subcategories >= 0
    end

    test "filters inactive categories from tree" do
      # Arrange
      create_category(%{name: "Active", is_active: true})
      create_category(%{name: "Inactive", is_active: false})

      query = GetCategoryTreeQuery.new(%{active_only: true})

      # Act
      {:ok, %{data: tree}} = CategoryQueryHandler.handle(query)

      # Assert
      assert Enum.all?(tree, &(&1.is_active == true))
    end
  end

  describe "handle GetCategoryPathQuery" do
    test "returns path from root to category", %{categories: categories} do
      # Arrange
      query =
        GetCategoryPathQuery.new(%{
          id: categories.iphones.id
        })

      # Act
      result = CategoryQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: path}} = result
      assert length(path) == 3
      assert hd(path).name == "Electronics"
      assert Enum.at(path, 1).name == "Smartphones"
      assert List.last(path).name == "iPhones"
    end

    test "returns single element for root category", %{categories: categories} do
      # Arrange
      query =
        GetCategoryPathQuery.new(%{
          id: categories.electronics.id
        })

      # Act
      {:ok, %{data: path}} = CategoryQueryHandler.handle(query)

      # Assert
      assert length(path) == 1
      assert hd(path).id == categories.electronics.id
    end

    test "returns error for non-existent category" do
      # Arrange
      query = GetCategoryPathQuery.new(%{id: UUID.uuid4()})

      # Act
      result = CategoryQueryHandler.handle(query)

      # Assert
      assert {:error, :not_found} = result
    end

    test "includes breadcrumb-friendly format", %{categories: categories} do
      # Arrange
      query =
        GetCategoryPathQuery.new(%{
          id: categories.iphones.id,
          format: "breadcrumb"
        })

      # Act
      {:ok, %{data: path}} = CategoryQueryHandler.handle(query)

      # Assert
      assert is_list(path)

      assert Enum.all?(path, fn item ->
               Map.has_key?(item, :id) &&
                 Map.has_key?(item, :name) &&
                 Map.has_key?(item, :url_slug)
             end)
    end
  end

  describe "performance and caching" do
    test "efficiently handles deep hierarchies" do
      # Create a deep hierarchy
      parent = create_category(%{name: "Root"})

      current = parent

      for level <- 1..10 do
        current =
          create_category(%{
            name: "Level #{level}",
            parent_id: current.id
          })
      end

      # Query should still be fast
      query = GetCategoryTreeQuery.new(%{})
      assert {:ok, _} = CategoryQueryHandler.handle(query)
    end

    test "handles categories with many children" do
      # Create category with many children
      parent = create_category(%{name: "Parent"})

      for i <- 1..50 do
        create_category(%{
          name: "Child #{i}",
          parent_id: parent.id
        })
      end

      query =
        GetCategoryQuery.new(%{
          id: parent.id,
          include_children: true
        })

      {:ok, category} = CategoryQueryHandler.handle(query)
      assert length(category.children) == 50
    end
  end

  # Helper functions
  defp create_test_categories do
    # Create hierarchy: Electronics -> Smartphones -> iPhones
    electronics =
      create_category(%{
        name: "Electronics",
        description: "Electronic devices"
      })

    smartphones =
      create_category(%{
        name: "Smartphones",
        description: "Mobile phones",
        parent_id: electronics.id
      })

    iphones =
      create_category(%{
        name: "iPhones",
        description: "Apple smartphones",
        parent_id: smartphones.id
      })

    # Create another root category
    clothing =
      create_category(%{
        name: "Clothing",
        description: "Apparel and accessories"
      })

    %{
      electronics: electronics,
      smartphones: smartphones,
      iphones: iphones,
      clothing: clothing
    }
  end

  defp create_category(attrs) do
    category_attrs = build(:category, attrs)

    # Update path based on parent
    path =
      if attrs[:parent_id] do
        case CategoryRepository.get(attrs[:parent_id]) do
          {:ok, parent} -> parent.path ++ [parent.id]
          _ -> []
        end
      else
        []
      end

    {:ok, category} = CategoryRepository.create(Map.put(category_attrs, :path, path))
    category
  end

  defp create_product(attrs) do
    product_attrs = build(:product, attrs)
    QueryService.Infrastructure.Repositories.ProductRepository.create(product_attrs)
  end
end
