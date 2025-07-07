defmodule ClientService.GraphQL.ProductIntegrationTest do
  use ExUnit.Case, async: false
  use ClientService.ConnCase
  
  import ElixirCqrs.GraphQLHelpers
  import ElixirCqrs.TestHelpers
  
  setup do
    # Setup both command and query databases
    setup_all_dbs(%{})
    
    # Create test data
    category = create_test_category()
    {:ok, category: category}
  end

  describe "products query" do
    test "returns list of products", %{category: category} do
      # Create products
      product1 = create_product_with_projection(%{
        name: "Product 1",
        price: Decimal.new("99.99"),
        category_id: category.id
      })
      product2 = create_product_with_projection(%{
        name: "Product 2",
        price: Decimal.new("149.99"),
        category_id: category.id
      })

      # Execute query
      result = run_query(list_products_query())

      # Assert
      data = assert_no_errors(result)
      products = data["products"]
      
      assert length(products) >= 2
      assert Enum.any?(products, & &1["id"] == product1.id)
      assert Enum.any?(products, & &1["id"] == product2.id)
    end

    test "filters products by price range" do
      # Create products with different prices
      create_product_with_projection(%{
        name: "Cheap Product",
        price: Decimal.new("25.00")
      })
      create_product_with_projection(%{
        name: "Expensive Product",
        price: Decimal.new("250.00")
      })

      # Query with price filter
      query = """
        query {
          products(minPrice: 50.0, maxPrice: 200.0) {
            id
            name
            price
          }
        }
      """
      
      result = run_query(query)
      data = assert_no_errors(result)
      
      products = data["products"]
      assert Enum.all?(products, fn p ->
        price = Decimal.new(p["price"])
        Decimal.compare(price, Decimal.new("50.0")) != :lt &&
        Decimal.compare(price, Decimal.new("200.0")) != :gt
      end)
    end

    test "paginates results" do
      # Create many products
      for i <- 1..15 do
        create_product_with_projection(%{
          name: "Product #{i}",
          price: Decimal.new("#{i * 10}.00")
        })
      end

      # First page
      query1 = """
        query {
          products(page: 1, pageSize: 5) {
            id
            name
          }
        }
      """
      
      result1 = run_query(query1)
      data1 = assert_no_errors(result1)
      assert length(data1["products"]) == 5

      # Second page
      query2 = """
        query {
          products(page: 2, pageSize: 5) {
            id
            name
          }
        }
      """
      
      result2 = run_query(query2)
      data2 = assert_no_errors(result2)
      assert length(data2["products"]) == 5
      
      # Ensure different products
      ids1 = Enum.map(data1["products"], & &1["id"])
      ids2 = Enum.map(data2["products"], & &1["id"])
      assert Enum.empty?(ids1 -- (ids1 -- ids2))
    end
  end

  describe "product query" do
    test "returns single product by ID", %{category: category} do
      # Create product
      product = create_product_with_projection(%{
        name: "Test Product",
        description: "Test Description",
        price: Decimal.new("99.99"),
        category_id: category.id
      })

      # Execute query
      result = run_query(get_product_query(), %{"id" => product.id})

      # Assert
      data = assert_no_errors(result)
      returned_product = data["product"]
      
      assert returned_product["id"] == product.id
      assert returned_product["name"] == "Test Product"
      assert returned_product["description"] == "Test Description"
      assert returned_product["price"] == "99.99"
      assert returned_product["category"]["id"] == category.id
    end

    test "returns null for non-existent product" do
      result = run_query(get_product_query(), %{"id" => UUID.uuid4()})
      
      data = assert_no_errors(result)
      assert data["product"] == nil
    end
  end

  describe "createProduct mutation" do
    test "successfully creates a product", %{category: category} do
      # Prepare input
      input = %{
        "name" => "New Product",
        "description" => "A new product",
        "price" => 129.99,
        "categoryId" => category.id
      }

      # Execute mutation
      result = run_query(create_product_mutation(), %{"input" => input})

      # Assert
      data = assert_no_errors(result)
      created_product = data["createProduct"]
      
      assert created_product["id"] != nil
      assert created_product["name"] == "New Product"
      assert created_product["price"] == "129.99"
      
      # Verify product exists in query service
      query_result = run_query(get_product_query(), %{"id" => created_product["id"]})
      query_data = assert_no_errors(query_result)
      assert query_data["product"] != nil
    end

    test "validates required fields" do
      # Missing name
      input = %{
        "description" => "No name",
        "price" => 99.99
      }

      result = run_query(create_product_mutation(), %{"input" => input})
      errors = assert_has_error(result, "name is required")
    end

    test "validates price is positive" do
      input = %{
        "name" => "Invalid Product",
        "price" => -10.00,
        "categoryId" => UUID.uuid4()
      }

      result = run_query(create_product_mutation(), %{"input" => input})
      errors = assert_has_error(result, "price must be positive")
    end
  end

  describe "updateProduct mutation" do
    test "successfully updates a product", %{category: category} do
      # Create product
      product = create_product_with_projection(%{
        name: "Original Name",
        price: Decimal.new("99.99"),
        category_id: category.id
      })

      # Update input
      input = %{
        "name" => "Updated Name",
        "price" => 149.99
      }

      # Execute mutation
      result = run_query(update_product_mutation(), %{
        "id" => product.id,
        "input" => input
      })

      # Assert
      data = assert_no_errors(result)
      updated_product = data["updateProduct"]
      
      assert updated_product["name"] == "Updated Name"
      assert updated_product["price"] == "149.99"
      
      # Verify update in query service
      query_result = run_query(get_product_query(), %{"id" => product.id})
      query_data = assert_no_errors(query_result)
      assert query_data["product"]["name"] == "Updated Name"
    end

    test "preserves unchanged fields" do
      product = create_product_with_projection(%{
        name: "Original",
        description: "Keep this",
        price: Decimal.new("99.99")
      })

      # Only update name
      input = %{"name" => "New Name"}
      
      result = run_query(update_product_mutation(), %{
        "id" => product.id,
        "input" => input
      })
      
      data = assert_no_errors(result)
      updated = data["updateProduct"]
      
      assert updated["name"] == "New Name"
      assert updated["description"] == "Keep this"
      assert updated["price"] == "99.99"
    end

    test "returns error for non-existent product" do
      input = %{"name" => "Won't work"}
      
      result = run_query(update_product_mutation(), %{
        "id" => UUID.uuid4(),
        "input" => input
      })
      
      assert_has_error(result, "Product not found")
    end
  end

  describe "deleteProduct mutation" do
    test "successfully deletes a product" do
      # Create product
      product = create_product_with_projection(%{name: "To Delete"})

      # Execute deletion
      result = run_query(delete_product_mutation(), %{"id" => product.id})

      # Assert
      data = assert_no_errors(result)
      assert data["deleteProduct"]["success"] == true
      
      # Verify product is gone
      query_result = run_query(get_product_query(), %{"id" => product.id})
      query_data = assert_no_errors(query_result)
      assert query_data["product"] == nil
    end

    test "returns appropriate message for non-existent product" do
      result = run_query(delete_product_mutation(), %{"id" => UUID.uuid4()})
      
      data = assert_no_errors(result)
      assert data["deleteProduct"]["success"] == false
      assert data["deleteProduct"]["message"] =~ "not found"
    end
  end

  describe "searchProducts query" do
    test "searches by product name" do
      create_product_with_projection(%{name: "Apple iPhone 15"})
      create_product_with_projection(%{name: "Samsung Galaxy"})
      create_product_with_projection(%{name: "Apple Watch"})

      query = """
        query {
          searchProducts(searchTerm: "Apple") {
            id
            name
          }
        }
      """
      
      result = run_query(query)
      data = assert_no_errors(result)
      
      products = data["searchProducts"]
      assert length(products) == 2
      assert Enum.all?(products, & String.contains?(&1["name"], "Apple"))
    end

    test "searches are case insensitive" do
      create_product_with_projection(%{name: "LAPTOP"})
      create_product_with_projection(%{name: "laptop"})
      create_product_with_projection(%{name: "Laptop"})

      query = """
        query {
          searchProducts(searchTerm: "laptop") {
            id
            name
          }
        }
      """
      
      result = run_query(query)
      data = assert_no_errors(result)
      
      assert length(data["searchProducts"]) == 3
    end
  end

  describe "productsByCategory query" do
    test "returns products for specific category", %{category: category} do
      # Create products in category
      create_product_with_projection(%{
        name: "Cat Product 1",
        category_id: category.id
      })
      create_product_with_projection(%{
        name: "Cat Product 2",
        category_id: category.id
      })
      # Product in different category
      create_product_with_projection(%{
        name: "Other Product",
        category_id: UUID.uuid4()
      })

      query = """
        query($categoryId: ID!) {
          productsByCategory(categoryId: $categoryId) {
            id
            name
            category {
              id
            }
          }
        }
      """
      
      result = run_query(query, %{"categoryId" => category.id})
      data = assert_no_errors(result)
      
      products = data["productsByCategory"]
      assert length(products) == 2
      assert Enum.all?(products, & &1["category"]["id"] == category.id)
    end
  end

  describe "error handling" do
    test "handles GraphQL validation errors" do
      # Invalid query structure
      query = """
        query {
          products {
            nonExistentField
          }
        }
      """
      
      result = run_query(query)
      assert_has_error(result, "Cannot query field")
    end

    test "handles internal server errors gracefully" do
      # This would typically involve mocking to force an error
      # For now, we'll test with an invalid operation
      
      query = """
        mutation {
          createProduct(input: null) {
            id
          }
        }
      """
      
      result = run_query(query)
      assert Map.has_key?(elem(result, 1), :errors)
    end
  end

  # Helper functions
  defp create_test_category do
    category_attrs = %{
      name: "Test Category",
      description: "For testing"
    }
    create_category_with_projection(category_attrs)
  end
end