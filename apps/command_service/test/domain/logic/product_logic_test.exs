defmodule CommandService.Domain.Logic.ProductLogicTest do
  use ExUnit.Case, async: true
  
  alias CommandService.Domain.Logic.ProductLogic
  alias CommandService.Domain.Entities.Product
  
  describe "validate_non_zero_price/1" do
    test "accepts positive prices" do
      assert ProductLogic.validate_non_zero_price(100) == :ok
      assert ProductLogic.validate_non_zero_price("100.50") == :ok
      assert ProductLogic.validate_non_zero_price(Decimal.new("99.99")) == :ok
    end
    
    test "rejects zero prices" do
      assert {:error, _} = ProductLogic.validate_non_zero_price(0)
      assert {:error, _} = ProductLogic.validate_non_zero_price("0")
      assert {:error, _} = ProductLogic.validate_non_zero_price(Decimal.new(0))
    end
    
    test "rejects negative prices" do
      assert {:error, _} = ProductLogic.validate_non_zero_price(-10)
      assert {:error, _} = ProductLogic.validate_non_zero_price("-50.00")
      assert {:error, _} = ProductLogic.validate_non_zero_price(Decimal.new(-100))
    end
    
    test "handles invalid formats" do
      assert {:error, "Invalid price format"} = ProductLogic.validate_non_zero_price("not a number")
    end
  end
  
  describe "filter_update_params/1" do
    test "removes nil values" do
      params = %{name: "Product", price: nil, category_id: "123"}
      filtered = ProductLogic.filter_update_params(params)
      
      assert filtered == %{name: "Product", category_id: "123"}
    end
    
    test "removes empty strings" do
      params = %{name: "", price: "100", category_id: "123"}
      filtered = ProductLogic.filter_update_params(params)
      
      assert filtered == %{price: "100", category_id: "123"}
    end
    
    test "keeps valid values" do
      params = %{name: "Product", price: "100", category_id: "123"}
      filtered = ProductLogic.filter_update_params(params)
      
      assert filtered == params
    end
  end
  
  describe "apply_price_update_rules/1" do
    test "allows valid prices" do
      assert {:ok, %{price: "100"}} = ProductLogic.apply_price_update_rules(%{price: "100"})
    end
    
    test "rejects zero prices" do
      assert {:error, _} = ProductLogic.apply_price_update_rules(%{price: "0"})
    end
    
    test "ignores when price is not present" do
      assert {:ok, %{name: "Product"}} = ProductLogic.apply_price_update_rules(%{name: "Product"})
    end
  end
  
  describe "calculate_discounted_price/2" do
    test "calculates correct discount" do
      {:ok, product} = Product.new("123", "Test", "100.00", "cat123")
      
      result = ProductLogic.calculate_discounted_price(product, 10)
      assert Decimal.equal?(result, Decimal.new("90.00"))
      
      result = ProductLogic.calculate_discounted_price(product, 25)
      assert Decimal.equal?(result, Decimal.new("75.00"))
    end
    
    test "handles 0% discount" do
      {:ok, product} = Product.new("123", "Test", "100.00", "cat123")
      
      result = ProductLogic.calculate_discounted_price(product, 0)
      assert Decimal.equal?(result, Decimal.new("100.00"))
    end
    
    test "handles 100% discount" do
      {:ok, product} = Product.new("123", "Test", "100.00", "cat123")
      
      result = ProductLogic.calculate_discounted_price(product, 100)
      assert Decimal.equal?(result, Decimal.new("0.00"))
    end
  end
  
  describe "classify_price_range/1" do
    test "classifies budget range" do
      assert ProductLogic.classify_price_range(Decimal.new("50")) == :budget
      assert ProductLogic.classify_price_range(Decimal.new("99.99")) == :budget
    end
    
    test "classifies standard range" do
      assert ProductLogic.classify_price_range(Decimal.new("100")) == :standard
      assert ProductLogic.classify_price_range(Decimal.new("499.99")) == :standard
    end
    
    test "classifies premium range" do
      assert ProductLogic.classify_price_range(Decimal.new("500")) == :premium
      assert ProductLogic.classify_price_range(Decimal.new("999.99")) == :premium
    end
    
    test "classifies luxury range" do
      assert ProductLogic.classify_price_range(Decimal.new("1000")) == :luxury
      assert ProductLogic.classify_price_range(Decimal.new("5000")) == :luxury
    end
  end
  
  describe "validate_product_name_format/1" do
    test "accepts valid names" do
      assert ProductLogic.validate_product_name_format("Product Name") == :ok
      assert ProductLogic.validate_product_name_format("Product-123") == :ok
      assert ProductLogic.validate_product_name_format("Product (Special)") == :ok
    end
    
    test "rejects too short names" do
      assert {:error, _} = ProductLogic.validate_product_name_format("A")
    end
    
    test "rejects too long names" do
      long_name = String.duplicate("a", 101)
      assert {:error, _} = ProductLogic.validate_product_name_format(long_name)
    end
    
    test "rejects invalid characters" do
      assert {:error, _} = ProductLogic.validate_product_name_format("Product@#$%")
    end
  end
  
  describe "calculate_total_price/1" do
    test "calculates total for multiple products" do
      {:ok, product1} = Product.new("1", "Product 1", "100.00", "cat1")
      {:ok, product2} = Product.new("2", "Product 2", "50.00", "cat1")
      {:ok, product3} = Product.new("3", "Product 3", "25.50", "cat1")
      
      total = ProductLogic.calculate_total_price([product1, product2, product3])
      assert Decimal.equal?(total, Decimal.new("175.50"))
    end
    
    test "handles empty list" do
      total = ProductLogic.calculate_total_price([])
      assert Decimal.equal?(total, Decimal.new("0"))
    end
  end
end