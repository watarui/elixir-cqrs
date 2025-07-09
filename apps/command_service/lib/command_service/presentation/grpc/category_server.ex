defmodule CommandService.Presentation.Grpc.CategoryServer do
  @moduledoc """
  カテゴリコマンドの gRPC サーバー実装
  """

  use GRPC.Server, service: ElixirCqrs.CategoryCommandService.Service

  alias CommandService.Infrastructure.CommandBus
  alias CommandService.Application.Commands.CategoryCommands
  alias ElixirCqrs.Common.Error

  require Logger

  @doc """
  カテゴリを作成
  """
  def create_category(request, _stream) do
    Logger.info("Creating category: #{request.name}")

    command = %CategoryCommands.CreateCategory{
      name: request.name,
      description: request.description
    }

    case CommandBus.dispatch(command) do
      {:ok, aggregate} ->
        %ElixirCqrs.CreateCategoryResponse{
          id: aggregate.id,
          category: %ElixirCqrs.Category{
            id: aggregate.id,
            name: request.name,
            description: request.description || "",
            parent_id: request.parent_id || "",
            product_count: 0,
            created_at: ElixirCqrs.Common.Timestamp.from_datetime(DateTime.utc_now()),
            updated_at: ElixirCqrs.Common.Timestamp.from_datetime(DateTime.utc_now())
          }
        }

      {:error, _reason} ->
        %ElixirCqrs.CreateCategoryResponse{
          id: "",
          category: nil
        }
    end
  end

  @doc """
  カテゴリを更新
  """
  def update_category(request, _stream) do
    Logger.info("Updating category: #{request.id}")

    command = %CategoryCommands.UpdateCategory{
      id: request.id,
      name: request.name
    }

    case CommandBus.dispatch(command) do
      {:ok, _aggregate} ->
        %ElixirCqrs.UpdateCategoryResponse{
          category: %ElixirCqrs.Category{
            id: request.id,
            name: request.name,
            description: request.description || "",
            parent_id: request.parent_id || "",
            product_count: 0,
            created_at: ElixirCqrs.Common.Timestamp.from_datetime(DateTime.utc_now()),
            updated_at: ElixirCqrs.Common.Timestamp.from_datetime(DateTime.utc_now())
          }
        }

      {:error, _reason} ->
        %ElixirCqrs.UpdateCategoryResponse{
          category: nil
        }
    end
  end

  @doc """
  カテゴリを削除
  """
  def delete_category(request, _stream) do
    Logger.info("Deleting category: #{request.id}")

    command = %CategoryCommands.DeleteCategory{
      id: request.id
    }

    case CommandBus.dispatch(command) do
      {:ok, _aggregate} ->
        %ElixirCqrs.DeleteCategoryResponse{
          success: true
        }

      {:error, _reason} ->
        %ElixirCqrs.DeleteCategoryResponse{
          success: false
        }
    end
  end
end
