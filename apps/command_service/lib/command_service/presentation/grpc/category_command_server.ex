defmodule CommandService.Presentation.Grpc.CategoryCommandServer do
  @moduledoc """
  Category Command gRPC Server Implementation
  """

  use GRPC.Server, service: Proto.CategoryCommand.Service

  alias CommandService.Application.Services.CategoryService

  def update_category(%Proto.CategoryUpParam{} = request, _stream) do
    case request.crud do
      :INSERT ->
        handle_create_category(request)

      :UPDATE ->
        handle_update_category(request)

      :DELETE ->
        handle_delete_category(request)

      _ ->
        {:error, "Unknown CRUD operation"}
    end
  end

  # プライベート関数

  defp handle_create_category(%Proto.CategoryUpParam{name: name}) do
    case CategoryService.create_category(%{name: name}) do
      {:ok, category} ->
        response = %Proto.CategoryUpResult{
          category: format_category(category),
          error: nil,
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.CategoryUpResult{
          category: nil,
          error: %Proto.Error{
            type: "CREATION_FAILED",
            message: "Failed to create category: #{inspect(reason)}"
          },
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        response
    end
  end

  defp handle_update_category(%Proto.CategoryUpParam{id: id, name: name}) do
    case CategoryService.update_category(id, %{name: name}) do
      {:ok, category} ->
        response = %Proto.CategoryUpResult{
          category: format_category(category),
          error: nil,
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.CategoryUpResult{
          category: nil,
          error: %Proto.Error{
            type: "UPDATE_FAILED",
            message: "Failed to update category: #{inspect(reason)}"
          },
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        response
    end
  end

  defp handle_delete_category(%Proto.CategoryUpParam{id: id}) do
    case CategoryService.delete_category(id) do
      :ok ->
        response = %Proto.CategoryUpResult{
          category: nil,
          error: nil,
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        response

      {:error, reason} ->
        response = %Proto.CategoryUpResult{
          category: nil,
          error: %Proto.Error{
            type: "DELETE_FAILED",
            message: "Failed to delete category: #{inspect(reason)}"
          },
          timestamp: Google.Protobuf.Timestamp.new(DateTime.utc_now())
        }

        response
    end
  end

  defp format_category(category) do
    %Proto.Category{
      id: category.id.value,
      name: category.name.value
    }
  end
end
