defmodule CommandService.Presentation.Grpc.ProductCommandServer do
  @moduledoc """
  Product Command gRPC Server Implementation
  """

  use GRPC.Server, service: Proto.ProductCommand.Service

  alias CommandService.Application.Services.ProductService

  def update_product(%Proto.ProductUpParam{} = request, _stream) do
    case request.crud do
      :INSERT ->
        handle_create_product(request)

      :UPDATE ->
        handle_update_product(request)

      :DELETE ->
        handle_delete_product(request)

      _ ->
        {:error, "Unknown CRUD operation"}
    end
  end

  # プライベート関数

  defp handle_create_product(%Proto.ProductUpParam{
         name: name,
         price: price,
         categoryId: category_id
       }) do
    case ProductService.create_product(%{name: name, price: price, category_id: category_id}) do
      {:ok, product} ->
        response = %Proto.ProductUpResult{
          product: format_product(product),
          error: nil,
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        {:ok, response}

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: %Proto.Error{
            type: "CREATION_FAILED",
            message: "Failed to create product: #{inspect(reason)}"
          },
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        {:ok, response}
    end
  end

  defp handle_update_product(%Proto.ProductUpParam{
         id: id,
         name: name,
         price: price,
         categoryId: category_id
       }) do
    case ProductService.update_product(id, %{name: name, price: price, category_id: category_id}) do
      {:ok, product} ->
        response = %Proto.ProductUpResult{
          product: format_product(product),
          error: nil,
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        {:ok, response}

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: %Proto.Error{
            type: "UPDATE_FAILED",
            message: "Failed to update product: #{inspect(reason)}"
          },
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        {:ok, response}
    end
  end

  defp handle_delete_product(%Proto.ProductUpParam{id: id}) do
    case ProductService.delete_product(id) do
      :ok ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: nil,
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        {:ok, response}

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: %Proto.Error{
            type: "DELETE_FAILED",
            message: "Failed to delete product: #{inspect(reason)}"
          },
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        {:ok, response}
    end
  end

  defp format_product(product) do
    %Proto.Product{
      id: product.id,
      name: product.name,
      price: product.price |> Decimal.to_float() |> trunc(),
      category: nil
    }
  end
end
