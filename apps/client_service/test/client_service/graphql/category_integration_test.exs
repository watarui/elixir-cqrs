defmodule ClientService.GraphQL.CategoryIntegrationTest do
  use ExUnit.Case, async: false
  use ClientService.ConnCase

  import ElixirCqrs.GraphQLHelpers
  import ElixirCqrs.TestHelpers

  setup do
    # Setup both command and query databases
    setup_all_dbs(%{})
    :ok
  end

  describe "categories query" do
    test "returns list of root categories" do
      # Create categories
      cat1 = create_category_with_projection(%{name: "Electronics"})
      cat2 = create_category_with_projection(%{name: "Clothing"})

      # Create subcategory (should not appear in root list)
      create_category_with_projection(%{
        name: "Smartphones",
        parent_id: cat1.id
      })

      # Execute query
      result = run_query(list_categories_query())

      # Assert
      data = assert_no_errors(result)
      categories = data["categories"]

      # Only root categories
      assert length(categories) == 2
      assert Enum.all?(categories, &(&1["parentId"] == nil))
      assert Enum.any?(categories, &(&1["name"] == "Electronics"))
      assert Enum.any?(categories, &(&1["name"] == "Clothing"))
    end

    test "includes children when requested" do
      # Create hierarchy
      parent = create_category_with_projection(%{name: "Electronics"})

      child1 =
        create_category_with_projection(%{
          name: "Computers",
          parent_id: parent.id
        })

      child2 =
        create_category_with_projection(%{
          name: "Audio",
          parent_id: parent.id
        })

      query = """
        query {
          categories {
            id
            name
            children {
              id
              name
              parentId
            }
          }
        }
      """

      result = run_query(query)
      data = assert_no_errors(result)

      electronics = Enum.find(data["categories"], &(&1["name"] == "Electronics"))
      assert length(electronics["children"]) == 2
      assert Enum.any?(electronics["children"], &(&1["name"] == "Computers"))
      assert Enum.any?(electronics["children"], &(&1["name"] == "Audio"))
    end
  end

  describe "category query" do
    test "returns single category with full details" do
      # Create category with parent
      parent = create_category_with_projection(%{name: "Parent"})

      category =
        create_category_with_projection(%{
          name: "Test Category",
          description: "Test Description",
          parent_id: parent.id
        })

      query = """
        query($id: ID!) {
          category(id: $id) {
            id
            name
            description
            path
            parent {
              id
              name
            }
          }
        }
      """

      result = run_query(query, %{"id" => category.id})
      data = assert_no_errors(result)

      cat = data["category"]
      assert cat["id"] == category.id
      assert cat["name"] == "Test Category"
      assert cat["description"] == "Test Description"
      assert cat["parent"]["id"] == parent.id
      assert cat["path"] == [parent.id]
    end

    test "returns null for non-existent category" do
      query = """
        query($id: ID!) {
          category(id: $id) {
            id
            name
          }
        }
      """

      result = run_query(query, %{"id" => UUID.uuid4()})
      data = assert_no_errors(result)

      assert data["category"] == nil
    end
  end

  describe "categoryTree query" do
    test "returns hierarchical category structure" do
      # Create tree structure
      electronics = create_category_with_projection(%{name: "Electronics"})

      computers =
        create_category_with_projection(%{
          name: "Computers",
          parent_id: electronics.id
        })

      laptops =
        create_category_with_projection(%{
          name: "Laptops",
          parent_id: computers.id
        })

      clothing = create_category_with_projection(%{name: "Clothing"})

      mens =
        create_category_with_projection(%{
          name: "Men's",
          parent_id: clothing.id
        })

      query = """
        query {
          categoryTree {
            id
            name
            children {
              id
              name
              children {
                id
                name
              }
            }
          }
        }
      """

      result = run_query(query)
      data = assert_no_errors(result)

      tree = data["categoryTree"]
      # Two root categories
      assert length(tree) == 2

      # Check Electronics branch
      elec = Enum.find(tree, &(&1["name"] == "Electronics"))
      assert length(elec["children"]) == 1
      comp = hd(elec["children"])
      assert comp["name"] == "Computers"
      assert length(comp["children"]) == 1
      assert hd(comp["children"])["name"] == "Laptops"
    end

    test "respects maxDepth parameter" do
      # Create deep hierarchy
      root = create_category_with_projection(%{name: "Root"})

      level1 =
        create_category_with_projection(%{
          name: "Level 1",
          parent_id: root.id
        })

      level2 =
        create_category_with_projection(%{
          name: "Level 2",
          parent_id: level1.id
        })

      query = """
        query {
          categoryTree(maxDepth: 1) {
            id
            name
            children {
              id
              name
              children {
                id
                name
              }
            }
          }
        }
      """

      result = run_query(query)
      data = assert_no_errors(result)

      root_node = Enum.find(data["categoryTree"], &(&1["name"] == "Root"))
      assert length(root_node["children"]) == 1
      # Children should not have their children loaded due to maxDepth
      assert hd(root_node["children"])["children"] == []
    end
  end

  describe "createCategory mutation" do
    test "successfully creates a root category" do
      input = %{
        "name" => "New Category",
        "description" => "A new category"
      }

      mutation = """
        mutation($input: CreateCategoryInput!) {
          createCategory(input: $input) {
            id
            name
            description
            parentId
            path
          }
        }
      """

      result = run_query(mutation, %{"input" => input})
      data = assert_no_errors(result)

      created = data["createCategory"]
      assert created["id"] != nil
      assert created["name"] == "New Category"
      assert created["parentId"] == nil
      assert created["path"] == []
    end

    test "creates subcategory with correct path" do
      parent = create_category_with_projection(%{name: "Parent"})

      input = %{
        "name" => "Subcategory",
        "description" => "A subcategory",
        "parentId" => parent.id
      }

      mutation = """
        mutation($input: CreateCategoryInput!) {
          createCategory(input: $input) {
            id
            name
            parentId
            path
          }
        }
      """

      result = run_query(mutation, %{"input" => input})
      data = assert_no_errors(result)

      created = data["createCategory"]
      assert created["parentId"] == parent.id
      assert created["path"] == [parent.id]
    end

    test "validates duplicate names at same level" do
      create_category_with_projection(%{name: "Existing"})

      input = %{"name" => "Existing"}

      mutation = """
        mutation($input: CreateCategoryInput!) {
          createCategory(input: $input) {
            id
          }
        }
      """

      result = run_query(mutation, %{"input" => input})
      assert_has_error(result, "already exists")
    end

    test "enforces maximum depth" do
      # Create chain up to max depth
      parent = create_category_with_projection(%{name: "Level 0"})

      for level <- 1..4 do
        parent =
          create_category_with_projection(%{
            name: "Level #{level}",
            parent_id: parent.id
          })
      end

      input = %{
        "name" => "Too Deep",
        "parentId" => parent.id
      }

      mutation = """
        mutation($input: CreateCategoryInput!) {
          createCategory(input: $input) {
            id
          }
        }
      """

      result = run_query(mutation, %{"input" => input})
      assert_has_error(result, "depth")
    end
  end

  describe "updateCategory mutation" do
    test "successfully updates category name and description" do
      category =
        create_category_with_projection(%{
          name: "Original",
          description: "Original description"
        })

      input = %{
        "name" => "Updated",
        "description" => "New description"
      }

      mutation = """
        mutation($id: ID!, $input: UpdateCategoryInput!) {
          updateCategory(id: $id, input: $input) {
            id
            name
            description
          }
        }
      """

      result =
        run_query(mutation, %{
          "id" => category.id,
          "input" => input
        })

      data = assert_no_errors(result)
      updated = data["updateCategory"]

      assert updated["name"] == "Updated"
      assert updated["description"] == "New description"
    end

    test "moves category to different parent" do
      parent1 = create_category_with_projection(%{name: "Parent 1"})
      parent2 = create_category_with_projection(%{name: "Parent 2"})

      category =
        create_category_with_projection(%{
          name: "Mobile",
          parent_id: parent1.id
        })

      input = %{"parentId" => parent2.id}

      mutation = """
        mutation($id: ID!, $input: UpdateCategoryInput!) {
          updateCategory(id: $id, input: $input) {
            id
            parentId
            path
          }
        }
      """

      result =
        run_query(mutation, %{
          "id" => category.id,
          "input" => input
        })

      data = assert_no_errors(result)
      updated = data["updateCategory"]

      assert updated["parentId"] == parent2.id
      assert updated["path"] == [parent2.id]
    end

    test "prevents circular references" do
      parent = create_category_with_projection(%{name: "Parent"})

      child =
        create_category_with_projection(%{
          name: "Child",
          parent_id: parent.id
        })

      # Try to make parent a child of its own child
      input = %{"parentId" => child.id}

      mutation = """
        mutation($id: ID!, $input: UpdateCategoryInput!) {
          updateCategory(id: $id, input: $input) {
            id
          }
        }
      """

      result =
        run_query(mutation, %{
          "id" => parent.id,
          "input" => input
        })

      assert_has_error(result, "circular")
    end
  end

  describe "deleteCategory mutation" do
    test "successfully deletes empty category" do
      category = create_category_with_projection(%{name: "To Delete"})

      mutation = """
        mutation($id: ID!) {
          deleteCategory(id: $id) {
            success
            message
          }
        }
      """

      result = run_query(mutation, %{"id" => category.id})
      data = assert_no_errors(result)

      assert data["deleteCategory"]["success"] == true

      # Verify deletion
      query_result =
        run_query(
          "query($id: ID!) { category(id: $id) { id } }",
          %{"id" => category.id}
        )

      query_data = assert_no_errors(query_result)
      assert query_data["category"] == nil
    end

    test "prevents deletion of category with subcategories" do
      parent = create_category_with_projection(%{name: "Parent"})

      create_category_with_projection(%{
        name: "Child",
        parent_id: parent.id
      })

      mutation = """
        mutation($id: ID!) {
          deleteCategory(id: $id) {
            success
            message
          }
        }
      """

      result = run_query(mutation, %{"id" => parent.id})
      data = assert_no_errors(result)

      assert data["deleteCategory"]["success"] == false
      assert data["deleteCategory"]["message"] =~ "subcategories"
    end

    test "prevents deletion of category with products" do
      category = create_category_with_projection(%{name: "With Products"})

      # Create a product in this category
      create_product_with_projection(%{
        name: "Product",
        category_id: category.id
      })

      mutation = """
        mutation($id: ID!) {
          deleteCategory(id: $id) {
            success
            message
          }
        }
      """

      result = run_query(mutation, %{"id" => category.id})
      data = assert_no_errors(result)

      assert data["deleteCategory"]["success"] == false
      assert data["deleteCategory"]["message"] =~ "products"
    end
  end

  describe "categoryPath query" do
    test "returns breadcrumb path for deep category" do
      # Create hierarchy
      electronics = create_category_with_projection(%{name: "Electronics"})

      computers =
        create_category_with_projection(%{
          name: "Computers",
          parent_id: electronics.id
        })

      laptops =
        create_category_with_projection(%{
          name: "Laptops",
          parent_id: computers.id
        })

      query = """
        query($id: ID!) {
          categoryPath(id: $id) {
            id
            name
          }
        }
      """

      result = run_query(query, %{"id" => laptops.id})
      data = assert_no_errors(result)

      path = data["categoryPath"]
      assert length(path) == 3
      assert Enum.at(path, 0)["name"] == "Electronics"
      assert Enum.at(path, 1)["name"] == "Computers"
      assert Enum.at(path, 2)["name"] == "Laptops"
    end
  end

  describe "complex scenarios" do
    test "reorganizes category hierarchy" do
      # Initial structure: Electronics -> Mobile -> Smartphones
      electronics = create_category_with_projection(%{name: "Electronics"})

      mobile =
        create_category_with_projection(%{
          name: "Mobile",
          parent_id: electronics.id
        })

      smartphones =
        create_category_with_projection(%{
          name: "Smartphones",
          parent_id: mobile.id
        })

      # Create new parent
      devices = create_category_with_projection(%{name: "Devices"})

      # Move Mobile to Devices
      mutation = """
        mutation($id: ID!, $input: UpdateCategoryInput!) {
          updateCategory(id: $id, input: $input) {
            id
            path
          }
        }
      """

      result =
        run_query(mutation, %{
          "id" => mobile.id,
          "input" => %{"parentId" => devices.id}
        })

      assert_no_errors(result)

      # Verify the entire subtree moved
      query_result =
        run_query(
          "query($id: ID!) { category(id: $id) { path } }",
          %{"id" => smartphones.id}
        )

      data = assert_no_errors(query_result)
      assert data["category"]["path"] == [devices.id, mobile.id]
    end
  end
end
