defmodule QueryService.Infrastructure.Projections.CategoryProjection do
  @moduledoc """
  カテゴリプロジェクション

  カテゴリ関連のイベントを処理し、Read Model を更新します
  """

  alias QueryService.Infrastructure.Repositories.CategoryRepository

  alias Shared.Domain.Events.CategoryEvents.{
    CategoryCreated,
    CategoryUpdated,
    CategoryDeleted
  }

  require Logger

  @doc """
  イベントを処理する
  """
  def handle_event(%{event_type: "CategoryCreated", event_data: data}) do
    event = CategoryCreated.from_json(data)

    attrs = %{
      id: event.id.value,
      name: event.name.value,
      description: event.description,
      parent_id: event.parent_id && event.parent_id.value,
      active: true,
      product_count: 0,
      metadata: %{},
      inserted_at: event.created_at,
      updated_at: event.created_at
    }

    case CategoryRepository.create(attrs) do
      {:ok, category} ->
        Logger.info("Category projection created: #{category.id}")
        {:ok, category}

      {:error, reason} ->
        Logger.error("Failed to create category projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%{event_type: "CategoryUpdated", event_data: data}) do
    event = CategoryUpdated.from_json(data)

    attrs = %{
      name: event.name.value,
      description: event.description,
      updated_at: event.updated_at
    }

    case CategoryRepository.update(event.id.value, attrs) do
      {:ok, category} ->
        Logger.info("Category projection updated: #{category.id}")
        {:ok, category}

      {:error, reason} ->
        Logger.error("Failed to update category projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%{event_type: "CategoryDeleted", event_data: data}) do
    event = CategoryDeleted.from_json(data)

    case CategoryRepository.delete(event.id.value) do
      {:ok, _} ->
        Logger.info("Category projection deleted: #{event.id.value}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete category projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(_event) do
    # 他のイベントは無視
    :ok
  end
end
