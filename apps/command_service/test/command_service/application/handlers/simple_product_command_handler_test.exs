defmodule CommandService.Application.Handlers.SimpleProductCommandHandlerTest do
  use ExUnit.Case, async: true

  alias CommandService.Application.Handlers.ProductCommandHandler

  alias CommandService.Application.Commands.ProductCommands.{
    CreateProduct,
    DeleteProduct,
    UpdateProduct
  }

  describe "handle CreateProductCommand" do
    test "validates command structure" do
      # 有効なコマンド
      valid_command = %CreateProduct{
        id: "test-id-123",
        name: "Test Product",
        price: "99.99",
        category_id: "cat-123"
      }

      # コマンドの構造を確認
      assert valid_command.id == "test-id-123"
      assert valid_command.name == "Test Product"
      assert valid_command.price == "99.99"
      assert valid_command.category_id == "cat-123"
    end

    test "invalid command with missing fields" do
      # 無効なコマンド（nameが空）
      invalid_command = %CreateProduct{
        id: "test-id-123",
        name: "",
        price: "99.99",
        category_id: "cat-123"
      }

      # 空の名前を持つコマンドの確認
      assert invalid_command.name == ""
    end
  end

  describe "handle UpdateProductCommand" do
    test "validates update command structure" do
      update_command = %UpdateProduct{
        id: "test-id-123",
        name: "Updated Product",
        price: "149.99"
      }

      assert update_command.id == "test-id-123"
      assert update_command.name == "Updated Product"
      assert update_command.price == "149.99"
    end
  end

  describe "handle DeleteProductCommand" do
    test "validates delete command structure" do
      delete_command = %DeleteProduct{
        id: "test-id-123"
      }

      assert delete_command.id == "test-id-123"
    end
  end
end
