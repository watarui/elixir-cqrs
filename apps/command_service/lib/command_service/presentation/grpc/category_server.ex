defmodule CommandService.Presentation.Grpc.CategoryServer do
  @moduledoc """
  カテゴリコマンドの gRPC サーバー実装
  """

  use GRPC.Server, service: ElixirCqrs.CategoryCommandService.Service

  alias CommandService.Domain.Aggregates.CategoryAggregate
  alias ElixirCqrs.Common.{Error, Result}
  alias Shared.Infrastructure.EventStore.EventStore

  require Logger

  @doc """
  カテゴリを作成
  """
  def create_category(request, _stream) do
    Logger.info("Creating category: #{request.name}")

    case CategoryAggregate.create(request.name) do
      {:ok, aggregate} ->
        # イベントストアに保存
        case save_aggregate(aggregate) do
          {:ok, _} ->
            %{
              result: Result.success("Category created successfully"),
              id: aggregate.id.value
            }

          {:error, reason} ->
            %{
              result:
                Result.failure(
                  Error.new("SAVE_FAILED", "Failed to save category: #{inspect(reason)}")
                ),
              id: ""
            }
        end

      {:error, reason} ->
        %{
          result: Result.failure(Error.new("VALIDATION_ERROR", reason)),
          id: ""
        }
    end
  end

  @doc """
  カテゴリを更新
  """
  def update_category(request, _stream) do
    Logger.info("Updating category: #{request.id}")

    with {:ok, aggregate} <- load_aggregate(request.id),
         {:ok, updated_aggregate} <- CategoryAggregate.update_name(aggregate, request.name),
         {:ok, _} <- save_aggregate(updated_aggregate) do
      %{result: Result.success("Category updated successfully")}
    else
      {:error, :not_found} ->
        %{result: Result.failure(Error.new("NOT_FOUND", "Category not found"))}

      {:error, reason} ->
        %{result: Result.failure(Error.new("UPDATE_FAILED", inspect(reason)))}
    end
  end

  @doc """
  カテゴリを削除
  """
  def delete_category(request, _stream) do
    Logger.info("Deleting category: #{request.id}")

    with {:ok, aggregate} <- load_aggregate(request.id),
         {:ok, deleted_aggregate} <- CategoryAggregate.delete(aggregate),
         {:ok, _} <- save_aggregate(deleted_aggregate) do
      %{result: Result.success("Category deleted successfully")}
    else
      {:error, :not_found} ->
        %{result: Result.failure(Error.new("NOT_FOUND", "Category not found"))}

      {:error, reason} ->
        %{result: Result.failure(Error.new("DELETE_FAILED", inspect(reason)))}
    end
  end

  # Private functions

  defp load_aggregate(id) do
    case EventStore.get_events(id) do
      {:ok, []} ->
        {:error, :not_found}

      {:ok, events} ->
        aggregate = CategoryAggregate.rebuild_from_events(events)
        {:ok, aggregate}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp save_aggregate(aggregate) do
    {cleared_aggregate, events} = CategoryAggregate.get_and_clear_uncommitted_events(aggregate)

    if length(events) > 0 do
      EventStore.append_events(
        aggregate.id.value,
        "category",
        events,
        aggregate.version - length(events),
        %{}
      )
    else
      {:ok, aggregate.version}
    end
  end
end
