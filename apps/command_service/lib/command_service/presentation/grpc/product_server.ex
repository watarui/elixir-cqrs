defmodule CommandService.Presentation.Grpc.ProductServer do
  @moduledoc """
  商品コマンドの gRPC サーバー実装
  """

  use GRPC.Server, service: ElixirCqrs.ProductCommandService.Service

  alias CommandService.Infrastructure.CommandBus
  alias CommandService.Application.Commands.ProductCommands
  # alias ElixirCqrs.Common.{Error, Result}  # Not used

  require Logger

  @doc """
  商品を作成
  """
  def create_product(request, _stream) do
    Logger.info("Creating product: #{request.name}")

    # 価格を処理
    price_amount = if request.price && request.price.amount, do: request.price.amount, else: 0

    command = %ProductCommands.CreateProduct{
      name: request.name,
      # cents to dollars
      price: price_amount / 100.0,
      category_id: request.category_id
    }

    case CommandBus.dispatch(command) do
      {:ok, aggregate} ->
        %ElixirCqrs.CreateProductResponse{
          id: aggregate.id,
          product: %ElixirCqrs.Product{
            id: aggregate.id,
            name: request.name,
            description: request.description || "",
            category_id: request.category_id,
            price: %ElixirCqrs.Money{
              amount: trunc(price_amount),
              currency:
                if(request.price && request.price.currency,
                  do: request.price.currency,
                  else: "USD"
                )
            },
            stock_quantity: request.initial_stock || 0,
            created_at: ElixirCqrs.Common.Timestamp.from_datetime(DateTime.utc_now()),
            updated_at: ElixirCqrs.Common.Timestamp.from_datetime(DateTime.utc_now())
          }
        }

      {:error, _reason} ->
        %ElixirCqrs.CreateProductResponse{
          id: "",
          product: nil
        }
    end
  end

  @doc """
  商品を更新
  """
  def update_product(request, _stream) do
    Logger.info("Updating product: #{request.id}")

    # 価格を処理
    price =
      if request.price && request.price.amount do
        # cents to dollars
        request.price.amount / 100.0
      else
        nil
      end

    command = %ProductCommands.UpdateProduct{
      id: request.id,
      name: request.name,
      price: price,
      category_id: request.category_id
    }

    case CommandBus.dispatch(command) do
      {:ok, _aggregate} ->
        %ElixirCqrs.UpdateProductResponse{
          product: %ElixirCqrs.Product{
            id: request.id,
            name: request.name,
            description: request.description || "",
            category_id: request.category_id,
            price: request.price || %ElixirCqrs.Money{amount: 0, currency: "USD"},
            stock_quantity: 0,
            created_at: ElixirCqrs.Common.Timestamp.from_datetime(DateTime.utc_now()),
            updated_at: ElixirCqrs.Common.Timestamp.from_datetime(DateTime.utc_now())
          }
        }

      {:error, _reason} ->
        %ElixirCqrs.UpdateProductResponse{
          product: nil
        }
    end
  end

  # NOTE: change_product_price RPC is not defined in the proto file
  # If needed, add it to the proto definition first

  @doc """
  商品を削除
  """
  def delete_product(request, _stream) do
    Logger.info("Deleting product: #{request.id}")

    command = %ProductCommands.DeleteProduct{
      id: request.id
    }

    case CommandBus.dispatch(command) do
      {:ok, _aggregate} ->
        %ElixirCqrs.DeleteProductResponse{
          success: true
        }

      {:error, _reason} ->
        %ElixirCqrs.DeleteProductResponse{
          success: false
        }
    end
  end
end
