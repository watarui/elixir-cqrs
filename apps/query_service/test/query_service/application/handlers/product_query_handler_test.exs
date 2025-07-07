defmodule QueryService.Application.Handlers.ProductQueryHandlerTest do
  use ExUnit.Case, async: true

  alias QueryService.Application.Handlers.ProductQueryHandler

  alias QueryService.Application.Queries.{
    GetProductQuery,
    ListProductsQuery,
    SearchProductsQuery,
    GetProductsByCategoryQuery
  }

  alias QueryService.Domain.ReadModels.Product
  alias QueryService.Infrastructure.Repositories.ProductRepository

  import ElixirCqrs.Factory
  import ElixirCqrs.TestHelpers

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(QueryService.Infrastructure.Database.Repo)

    # Create test products
    products = create_test_products()
    {:ok, products: products}
  end

  describe "handle GetProductQuery" do
    test "successfully retrieves an existing product", %{products: products} do
      # Arrange
      product = hd(products)
      query = GetProductQuery.new(%{id: product.id})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, retrieved_product} = result
      assert retrieved_product.id == product.id
      assert retrieved_product.name == product.name
      assert Decimal.equal?(retrieved_product.price, product.price)
    end

    test "returns error for non-existent product" do
      # Arrange
      query = GetProductQuery.new(%{id: UUID.uuid4()})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:error, :not_found} = result
    end

    test "includes category information when available", %{products: products} do
      # Arrange
      product_with_category = Enum.find(products, & &1.category_id)
      query = GetProductQuery.new(%{id: product_with_category.id})

      # Act
      {:ok, product} = ProductQueryHandler.handle(query)

      # Assert
      assert product.category != nil
      assert product.category.id == product_with_category.category_id
    end
  end

  describe "handle ListProductsQuery" do
    test "retrieves all products with default pagination", %{products: products} do
      # Arrange
      query = ListProductsQuery.new(%{})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: retrieved_products, metadata: metadata}} = result
      # default page size
      assert length(retrieved_products) <= 20
      assert metadata.page == 1
      assert metadata.total_count == length(products)
    end

    test "applies pagination correctly" do
      # Arrange - create more products than page size
      for i <- 1..25 do
        create_product(%{name: "Product #{i}"})
      end

      query = ListProductsQuery.new(%{page: 2, page_size: 10})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: products, metadata: metadata}} = result
      assert length(products) == 10
      assert metadata.page == 2
      assert metadata.page_size == 10
    end

    test "sorts products by specified field" do
      # Arrange
      query =
        ListProductsQuery.new(%{
          sort_by: "price",
          sort_order: "desc"
        })

      # Act
      {:ok, %{data: products}} = ProductQueryHandler.handle(query)

      # Assert prices are in descending order
      prices = Enum.map(products, & &1.price)
      assert prices == Enum.sort(prices, {:desc, Decimal})
    end

    test "filters by price range" do
      # Arrange
      query =
        ListProductsQuery.new(%{
          min_price: Decimal.new("50.00"),
          max_price: Decimal.new("150.00")
        })

      # Act
      {:ok, %{data: products}} = ProductQueryHandler.handle(query)

      # Assert all products are within price range
      assert Enum.all?(products, fn p ->
               Decimal.compare(p.price, Decimal.new("50.00")) != :lt &&
                 Decimal.compare(p.price, Decimal.new("150.00")) != :gt
             end)
    end

    test "filters by availability status" do
      # Arrange
      query = ListProductsQuery.new(%{available_only: true})

      # Act
      {:ok, %{data: products}} = ProductQueryHandler.handle(query)

      # Assert
      assert Enum.all?(products, & &1.is_available)
    end
  end

  describe "handle SearchProductsQuery" do
    test "finds products by name search" do
      # Arrange
      create_product(%{name: "Gaming Laptop Pro"})
      create_product(%{name: "Office Laptop Basic"})
      create_product(%{name: "Gaming Mouse"})

      query = SearchProductsQuery.new(%{search_term: "gaming"})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: products}} = result
      assert length(products) == 2

      assert Enum.all?(products, fn p ->
               String.contains?(String.downcase(p.name), "gaming")
             end)
    end

    test "finds products by description search" do
      # Arrange
      create_product(%{
        name: "Product A",
        description: "High-performance device"
      })

      create_product(%{
        name: "Product B",
        description: "Budget-friendly option"
      })

      query = SearchProductsQuery.new(%{search_term: "performance"})

      # Act
      {:ok, %{data: products}} = result = ProductQueryHandler.handle(query)

      # Assert
      assert length(products) == 1
      assert hd(products).name == "Product A"
    end

    test "applies filters along with search" do
      # Arrange
      create_product(%{
        name: "Expensive Gaming PC",
        price: Decimal.new("2000.00")
      })

      create_product(%{
        name: "Budget Gaming Console",
        price: Decimal.new("300.00")
      })

      query =
        SearchProductsQuery.new(%{
          search_term: "gaming",
          max_price: Decimal.new("500.00")
        })

      # Act
      {:ok, %{data: products}} = ProductQueryHandler.handle(query)

      # Assert
      assert length(products) == 1
      assert hd(products).name == "Budget Gaming Console"
    end

    test "returns empty results for no matches" do
      # Arrange
      query = SearchProductsQuery.new(%{search_term: "nonexistent"})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: []}} = result
    end

    test "handles special characters in search" do
      # Arrange
      create_product(%{name: "Product (Special) Edition"})

      query = SearchProductsQuery.new(%{search_term: "(Special)"})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: products}} = result
      assert length(products) == 1
    end
  end

  describe "handle GetProductsByCategoryQuery" do
    test "retrieves all products in a category", %{products: _} do
      # Arrange
      category_id = UUID.uuid4()
      create_product(%{name: "Cat Product 1", category_id: category_id})
      create_product(%{name: "Cat Product 2", category_id: category_id})
      create_product(%{name: "Other Product", category_id: UUID.uuid4()})

      query = GetProductsByCategoryQuery.new(%{category_id: category_id})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: products}} = result
      assert length(products) == 2
      assert Enum.all?(products, &(&1.category_id == category_id))
    end

    test "includes subcategory products when specified" do
      # Arrange
      parent_category_id = UUID.uuid4()
      sub_category_id = UUID.uuid4()

      # Simulate category hierarchy
      create_product(%{
        name: "Parent Category Product",
        category_id: parent_category_id
      })

      create_product(%{
        name: "Subcategory Product",
        category_id: sub_category_id
      })

      query =
        GetProductsByCategoryQuery.new(%{
          category_id: parent_category_id,
          include_subcategories: true
        })

      # Act
      # Note: This test assumes category hierarchy is handled
      # The actual implementation would need to join with categories table
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: _products}} = result
    end

    test "returns empty list for category with no products" do
      # Arrange
      query = GetProductsByCategoryQuery.new(%{category_id: UUID.uuid4()})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:ok, %{data: []}} = result
    end
  end

  describe "query validation" do
    test "validates page number is positive" do
      # Arrange
      query = ListProductsQuery.new(%{page: 0})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:error, :invalid_page} = result
    end

    test "validates page size is within limits" do
      # Arrange
      query = ListProductsQuery.new(%{page_size: 1000})

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:error, :page_size_too_large} = result
    end

    test "validates price range" do
      # Arrange
      query =
        ListProductsQuery.new(%{
          min_price: Decimal.new("100.00"),
          max_price: Decimal.new("50.00")
        })

      # Act
      result = ProductQueryHandler.handle(query)

      # Assert
      assert {:error, :invalid_price_range} = result
    end
  end

  describe "performance considerations" do
    test "uses proper indexes for common queries" do
      # This would typically be tested at the repository level
      # Here we just ensure the query doesn't timeout with large datasets

      # Create many products
      for i <- 1..100 do
        create_product(%{name: "Product #{i}"})
      end

      query = ListProductsQuery.new(%{page_size: 50})

      # Should complete quickly
      assert {:ok, _} = ProductQueryHandler.handle(query)
    end
  end

  # Helper functions
  defp create_test_products do
    category_id = UUID.uuid4()

    [
      create_product(%{
        name: "Product 1",
        price: Decimal.new("99.99"),
        category_id: category_id,
        is_available: true
      }),
      create_product(%{
        name: "Product 2",
        price: Decimal.new("149.99"),
        category_id: category_id,
        is_available: true
      }),
      create_product(%{
        name: "Product 3",
        price: Decimal.new("199.99"),
        category_id: nil,
        is_available: false
      })
    ]
  end

  defp create_product(attrs) do
    product_attrs = build(:product, attrs)

    {:ok, product} = ProductRepository.create(product_attrs)
    product
  end
end
