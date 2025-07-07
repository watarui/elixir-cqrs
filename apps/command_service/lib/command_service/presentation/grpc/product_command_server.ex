defmodule CommandService.Presentation.Grpc.ProductCommandServer do
  @moduledoc """
  Product Command gRPC Server Implementation
  """

  use GRPC.Server, service: Proto.ProductCommand.Service

  alias CommandService.Application.Services.ProductService

  # Helper function to convert DateTime to Google.Protobuf.Timestamp
  defp datetime_to_timestamp(%DateTime{} = datetime) do
    seconds = DateTime.to_unix(datetime)
    nanos = datetime.microsecond |> elem(0) |> Kernel.*(1000)
    
    %Google.Protobuf.Timestamp{
      seconds: seconds,
      nanos: nanos
    }
  end

  defp datetime_to_timestamp(nil), do: nil

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
    case ProductService.create_product(%{name: name, price: to_string(price), category_id: category_id}) do
      {:ok, product} ->
        response = %Proto.ProductUpResult{
          product: format_product(product),
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: %Proto.Error{
            type: "CREATION_FAILED",
            message: "Failed to create product: #{inspect(reason)}"
          },
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  defp handle_update_product(%Proto.ProductUpParam{
         id: id,
         name: name,
         price: price,
         categoryId: category_id
       }) do
    case ProductService.update_product(id, %{name: name, price: if(price, do: to_string(price), else: nil), category_id: category_id}) do
      {:ok, product} ->
        response = %Proto.ProductUpResult{
          product: format_product(product),
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: %Proto.Error{
            type: "UPDATE_FAILED",
            message: "Failed to update product: #{inspect(reason)}"
          },
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  defp handle_delete_product(%Proto.ProductUpParam{id: id}) do
    case ProductService.delete_product(id) do
      :ok ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: nil,
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.ProductUpResult{
          product: nil,
          error: %Proto.Error{
            type: "DELETE_FAILED",
            message: "Failed to delete product: #{inspect(reason)}"
          },
          timestamp: datetime_to_timestamp(DateTime.utc_now())
        }

        response
    end
  end

  defp format_product(product) do
    %Proto.Product{
      id: CommandService.Domain.Entities.Product.id(product),
      name: CommandService.Domain.Entities.Product.name(product),
      price: CommandService.Domain.Entities.Product.price(product) |> Decimal.to_float() |> trunc(),
      category: nil
    }
  end
end
