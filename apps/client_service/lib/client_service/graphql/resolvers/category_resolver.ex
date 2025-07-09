defmodule ClientService.GraphQL.Resolvers.CategoryResolver do
  @moduledoc """
  カテゴリ関連の GraphQL リゾルバー
  """

  alias ClientService.Infrastructure.GrpcConnections
  alias ElixirCqrs.CategoryCommandService.Stub, as: CategoryCommandStub
  alias ElixirCqrs.CategoryQueryService.Stub, as: CategoryQueryStub

  require Logger

  @doc """
  カテゴリを取得
  """
  def get_category(_parent, %{id: id}, _resolution) do
    # TODO: Query Service への gRPC 呼び出し
    {:ok,
     %{
       id: id,
       name: "Sample Category",
       product_count: 0,
       created_at: DateTime.utc_now(),
       updated_at: DateTime.utc_now()
     }}
  end

  @doc """
  カテゴリ一覧を取得
  """
  def list_categories(_parent, args, _resolution) do
    case GrpcConnections.get_query_channel() do
      nil ->
        {:error, "Query Service unavailable"}

      channel ->
        # ページ番号から offset を計算
        page = Map.get(args, :page, 1)
        page_size = Map.get(args, :page_size, 20)
        offset = (page - 1) * page_size

        request = %ElixirCqrs.ListCategoriesRequest{
          pagination: %ElixirCqrs.Pagination{
            limit: page_size,
            offset: offset
          }
        }

        case CategoryQueryStub.list_categories(channel, request) do
          {:ok, response} ->
            categories =
              Enum.map(response.categories, fn cat ->
                %{
                  id: cat.id,
                  name: cat.name,
                  description: cat.description,
                  product_count: cat.product_count || 0,
                  created_at: DateTime.from_unix!(cat.created_at || 0),
                  updated_at: DateTime.from_unix!(cat.updated_at || 0)
                }
              end)

            {:ok, categories}

          {:error, reason} ->
            Logger.error("Failed to list categories: #{inspect(reason)}")
            {:ok, []}
        end
    end
  end

  @doc """
  カテゴリを検索
  """
  def search_categories(_parent, %{search_term: search_term} = args, _resolution) do
    # TODO: Query Service への gRPC 呼び出し
    {:ok, []}
  end

  @doc """
  カテゴリを作成
  """
  def create_category(_parent, %{input: input}, _resolution) do
    case GrpcConnections.get_command_channel() do
      nil ->
        {:error, "Command Service unavailable"}

      channel ->
        request = %ElixirCqrs.CreateCategoryRequest{
          name: input.name,
          description: Map.get(input, :description, ""),
          parent_id: Map.get(input, :parent_id, "")
        }

        case CategoryCommandStub.create_category(channel, request) do
          {:ok, response} ->
            if response.result.success do
              # クエリサービスから作成したカテゴリを取得
              # 今は一旦レスポンスだけ返す
              {:ok,
               %{
                 id: response.id,
                 name: input.name,
                 description: Map.get(input, :description, ""),
                 product_count: 0,
                 created_at: DateTime.utc_now(),
                 updated_at: DateTime.utc_now()
               }}
            else
              {:error, response.result.error.message}
            end

          {:error, reason} ->
            Logger.error("Failed to create category: #{inspect(reason)}")
            {:error, "Failed to create category"}
        end
    end
  end

  @doc """
  カテゴリを更新
  """
  def update_category(_parent, %{id: id, input: input}, _resolution) do
    # TODO: Command Service への gRPC 呼び出し
    {:ok,
     %{
       id: id,
       name: input.name,
       product_count: 0,
       created_at: DateTime.utc_now(),
       updated_at: DateTime.utc_now()
     }}
  end

  @doc """
  カテゴリを削除
  """
  def delete_category(_parent, %{id: id}, _resolution) do
    # TODO: Command Service への gRPC 呼び出し
    {:ok, %{success: true, message: "Category deleted successfully"}}
  end
end
