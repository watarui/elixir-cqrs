defmodule ClientService.GraphQL.Resolvers.CategoryResolverPubsub do
  @moduledoc """
  カテゴリ関連の GraphQL リゾルバー (PubSub版)
  """

  alias ClientService.Infrastructure.{RemoteCommandBus, RemoteQueryBus}
  alias QueryService.Application.Queries.CategoryQueries
  alias CommandService.Application.Commands.CategoryCommands

  require Logger

  @doc """
  カテゴリを取得
  """
  def get_category(_parent, %{id: id}, _resolution) do
    {:ok, query} = CategoryQueries.GetCategory.validate(%{id: id})

    case RemoteQueryBus.send_query(query) do
      {:ok, category} ->
        {:ok, transform_category(category)}

      {:error, reason} ->
        Logger.error("Failed to get category: #{inspect(reason)}")
        {:error, "Category not found"}
    end
  end

  @doc """
  カテゴリ一覧を取得
  """
  def list_categories(_parent, args, _resolution) do
    # ページ番号から offset を計算
    page = Map.get(args, :page, 1)
    page_size = Map.get(args, :page_size, 20)
    offset = (page - 1) * page_size

    {:ok, query} =
      CategoryQueries.ListCategories.validate(%{
        limit: page_size,
        offset: offset
      })

    case RemoteQueryBus.send_query(query) do
      {:ok, categories} ->
        {:ok, Enum.map(categories, &transform_category/1)}

      {:error, reason} ->
        Logger.error("Failed to list categories: #{inspect(reason)}")
        {:ok, []}
    end
  end

  @doc """
  カテゴリを検索
  """
  def search_categories(_parent, %{search_term: search_term} = args, _resolution) do
    page = Map.get(args, :page, 1)
    page_size = Map.get(args, :page_size, 20)
    offset = (page - 1) * page_size

    {:ok, query} =
      CategoryQueries.SearchCategories.validate(%{
        search_term: search_term,
        limit: page_size,
        offset: offset
      })

    case RemoteQueryBus.send_query(query) do
      {:ok, categories} ->
        {:ok, Enum.map(categories, &transform_category/1)}

      {:error, reason} ->
        Logger.error("Failed to search categories: #{inspect(reason)}")
        {:ok, []}
    end
  end

  @doc """
  カテゴリを作成
  """
  def create_category(_parent, %{input: input}, _resolution) do
    params = %{
      name: input.name,
      description: Map.get(input, :description),
      metadata: %{}
    }

    {:ok, command} = CategoryCommands.CreateCategory.validate(params)

    case RemoteCommandBus.send_command(command) do
      {:ok, aggregate} ->
        # 作成されたカテゴリの情報を返す
        {:ok,
         %{
           id: aggregate.id.value,
           name: aggregate.name.value,
           description: aggregate.description,
           product_count: 0,
           created_at: aggregate.created_at,
           updated_at: aggregate.updated_at
         }}

      {:error, reason} ->
        Logger.error("Failed to create category: #{inspect(reason)}")
        {:error, "Failed to create category: #{inspect(reason)}"}
    end
  end

  @doc """
  カテゴリを更新
  """
  def update_category(_parent, %{id: id, input: input}, _resolution) do
    params = %{
      id: id,
      name: input.name,
      description: Map.get(input, :description),
      metadata: %{}
    }

    {:ok, command} = CategoryCommands.UpdateCategory.validate(params)

    case RemoteCommandBus.send_command(command) do
      {:ok, aggregate} ->
        {:ok,
         %{
           id: aggregate.id.value,
           name: aggregate.name.value,
           description: aggregate.description,
           product_count: 0,
           created_at: aggregate.created_at,
           updated_at: aggregate.updated_at
         }}

      {:error, reason} ->
        Logger.error("Failed to update category: #{inspect(reason)}")
        {:error, "Failed to update category: #{inspect(reason)}"}
    end
  end

  @doc """
  カテゴリを削除
  """
  def delete_category(_parent, %{id: id}, _resolution) do
    params = %{id: id, metadata: %{}}
    {:ok, command} = CategoryCommands.DeleteCategory.validate(params)

    case RemoteCommandBus.send_command(command) do
      {:ok, _} ->
        {:ok, %{success: true, message: "Category deleted successfully"}}

      {:error, reason} ->
        Logger.error("Failed to delete category: #{inspect(reason)}")
        {:error, "Failed to delete category: #{inspect(reason)}"}
    end
  end

  # プライベート関数

  defp transform_category(category) do
    %{
      id: category.id,
      name: category.name,
      description: category.description,
      parent_id: category.parent_id,
      product_count: category.product_count || 0,
      created_at: category.created_at,
      updated_at: category.updated_at
    }
  end
end
