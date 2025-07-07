defmodule CommandService.Domain.Logic.CategoryLogicTest do
  use ExUnit.Case, async: true

  alias CommandService.Domain.Logic.CategoryLogic
  alias CommandService.Domain.Entities.Category

  describe "validate_category_name/1" do
    test "accepts valid names" do
      assert CategoryLogic.validate_category_name("Electronics") == :ok
      assert CategoryLogic.validate_category_name("Home & Garden") == :ok
      assert CategoryLogic.validate_category_name("Category-123") == :ok
    end

    test "rejects too short names" do
      assert {:error, _} = CategoryLogic.validate_category_name("A")
    end

    test "rejects too long names" do
      long_name = String.duplicate("a", 51)
      assert {:error, _} = CategoryLogic.validate_category_name(long_name)
    end

    test "rejects invalid characters" do
      assert {:error, _} = CategoryLogic.validate_category_name("Category@#$")
    end
  end

  describe "calculate_hierarchy_depth/1" do
    test "calculates single level" do
      assert CategoryLogic.calculate_hierarchy_depth("Electronics") == 1
    end

    test "calculates multiple levels" do
      assert CategoryLogic.calculate_hierarchy_depth("Electronics/Computers/Laptops") == 3
    end

    test "handles empty segments" do
      assert CategoryLogic.calculate_hierarchy_depth("Electronics//Laptops") == 3
    end
  end

  describe "normalize_category_path/1" do
    test "normalizes path with extra spaces" do
      assert CategoryLogic.normalize_category_path("Electronics / Computers / Laptops") ==
               "Electronics/Computers/Laptops"
    end

    test "removes empty segments" do
      assert CategoryLogic.normalize_category_path("Electronics//Computers") ==
               "Electronics/Computers"
    end

    test "trims whitespace" do
      assert CategoryLogic.normalize_category_path(" Electronics / Computers ") ==
               "Electronics/Computers"
    end
  end

  describe "build_category_tree/1" do
    test "builds tree from flat list" do
      categories = [
        %{id: "1", name: "Electronics", parent_id: nil},
        %{id: "2", name: "Computers", parent_id: "1"},
        %{id: "3", name: "Laptops", parent_id: "2"},
        %{id: "4", name: "Clothing", parent_id: nil}
      ]

      tree = CategoryLogic.build_category_tree(categories)

      assert length(tree) == 2
      assert Enum.find(tree, &(&1.category.name == "Electronics"))
      assert Enum.find(tree, &(&1.category.name == "Clothing"))

      electronics = Enum.find(tree, &(&1.category.name == "Electronics"))
      assert length(electronics.children) == 1
      assert hd(electronics.children).category.name == "Computers"
    end

    test "handles empty list" do
      assert CategoryLogic.build_category_tree([]) == []
    end
  end

  describe "has_duplicate_name?/2" do
    test "detects duplicate names case-insensitive" do
      {:ok, cat1} = Category.new("1", "Electronics")
      {:ok, cat2} = Category.new("2", "Clothing")

      categories = [cat1, cat2]

      assert CategoryLogic.has_duplicate_name?(categories, "electronics") == true
      assert CategoryLogic.has_duplicate_name?(categories, "ELECTRONICS") == true
      assert CategoryLogic.has_duplicate_name?(categories, "Books") == false
    end
  end

  describe "sort_alphabetically/1" do
    test "sorts categories by name" do
      {:ok, cat1} = Category.new("1", "Zebra")
      {:ok, cat2} = Category.new("2", "Apple")
      {:ok, cat3} = Category.new("3", "Banana")

      sorted = CategoryLogic.sort_alphabetically([cat1, cat2, cat3])
      names = Enum.map(sorted, &Category.name/1)

      assert names == ["Apple", "Banana", "Zebra"]
    end

    test "handles case-insensitive sorting" do
      {:ok, cat1} = Category.new("1", "zebra")
      {:ok, cat2} = Category.new("2", "Apple")
      {:ok, cat3} = Category.new("3", "BANANA")

      sorted = CategoryLogic.sort_alphabetically([cat1, cat2, cat3])
      names = Enum.map(sorted, &Category.name/1)

      assert names == ["Apple", "BANANA", "zebra"]
    end
  end

  describe "calculate_statistics/2" do
    test "calculates correct statistics" do
      {:ok, cat1} = Category.new("1", "Electronics")
      {:ok, cat2} = Category.new("2", "Clothing")
      {:ok, cat3} = Category.new("3", "Books")

      categories = [cat1, cat2, cat3]
      product_counts = %{"1" => 10, "2" => 5, "3" => 0}

      stats = CategoryLogic.calculate_statistics(categories, product_counts)

      assert stats.total_categories == 3
      assert stats.categories_with_products == 2
      assert stats.empty_categories == 1
      assert stats.average_products_per_category == 5.0
    end

    test "handles empty categories list" do
      stats = CategoryLogic.calculate_statistics([], %{})

      assert stats.total_categories == 0
      assert stats.categories_with_products == 0
      assert stats.empty_categories == 0
      assert stats.average_products_per_category == 0.0
    end
  end
end
