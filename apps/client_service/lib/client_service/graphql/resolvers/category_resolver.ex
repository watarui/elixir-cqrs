defmodule ClientService.GraphQL.Resolvers.CategoryResolver do
  @moduledoc """
  カテゴリ用 GraphQL リゾルバー

  Command Service と Query Service への gRPC 通信を行います
  """

  alias ClientService.Infrastructure.GrpcConnections

  alias Query.{
    CategoryQueryRequest,
    CategoryByNameRequest,
    CategorySearchRequest,
    CategoryPaginationRequest,
    CategoryExistsRequest,
    Empty
  }

  alias Proto.CategoryUpParam

  @doc """
  IDでカテゴリを取得
  """
  def get_category(_parent, %{id: id}, _context) do
    id
    |> build_category_query_request()
    |> execute_category_query()
    |> handle_category_response()
  end

  @doc """
  名前でカテゴリを取得
  """
  def get_category_by_name(_parent, %{name: name}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %CategoryByNameRequest{name: name},
         {:ok, response} <- Query.CategoryQuery.Stub.get_category_by_name(channel, request) do
      {:ok, format_category(response.category)}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get category by name: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  全カテゴリを取得
  """
  def list_categories(_parent, _args, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %Empty{},
         {:ok, response} <- Query.CategoryQuery.Stub.list_categories(channel, request) do
      categories = Enum.map(response.categories, &format_category/1)
      {:ok, categories}
    else
      {:error, reason} ->
        {:error, "Failed to get categories: #{inspect(reason)}"}

      %GRPC.RPCError{status: status, message: message} = error ->
        {:error,
         "gRPC error - Status: #{status}, Message: #{message}, Full Error: #{inspect(error)}"}

      other ->
        {:error, "Unexpected error: #{inspect(other)}"}
    end
  end

  @doc """
  カテゴリを検索
  """
  def search_categories(_parent, %{search_term: search_term}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %CategorySearchRequest{search_term: search_term},
         {:ok, response} <- Query.CategoryQuery.Stub.search_categories(channel, request) do
      categories = Enum.map(response.categories, &format_category/1)
      {:ok, categories}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to search categories: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  ページネーション付きカテゴリ一覧
  """
  def list_categories_paginated(_parent, %{page: page, per_page: per_page}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %CategoryPaginationRequest{page: page, per_page: per_page},
         {:ok, response} <- Query.CategoryQuery.Stub.list_categories_paginated(channel, request) do
      categories = Enum.map(response.categories, &format_category/1)
      {:ok, categories}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get paginated categories: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリ統計情報を取得
  """
  def get_statistics(_parent, _args, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %Empty{},
         {:ok, response} <- Query.CategoryQuery.Stub.get_category_statistics(channel, request) do
      statistics = %{
        total_count: response.total_count,
        has_categories: response.has_categories,
        categories_with_timestamps: response.categories_with_timestamps
      }

      {:ok, statistics}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get category statistics: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリ存在チェック
  """
  def category_exists(_parent, %{id: id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %CategoryExistsRequest{id: id},
         {:ok, response} <- Query.CategoryQuery.Stub.category_exists(channel, request) do
      {:ok, response.exists}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to check category existence: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリを作成
  """
  def create_category(_parent, %{input: input}, _context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %CategoryUpParam{
           crud: :INSERT,
           name: input.name
         },
         {:ok, response} <- Proto.CategoryCommand.Stub.update_category(channel, request) do
      # 作成成功通知を送信
      # TODO: Add PubSub support
      # Absinthe.Subscription.publish(context.pubsub, response.category, category_created: "*")

      {:ok, format_category(response.category)}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to create category: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリを更新
  """
  def update_category(_parent, %{input: input}, _context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %CategoryUpParam{
           crud: :UPDATE,
           id: input.id,
           name: input.name
         },
         {:ok, response} <- Proto.CategoryCommand.Stub.update_category(channel, request) do
      # 更新成功通知を送信
      # TODO: Add PubSub support
      # Absinthe.Subscription.publish(context.pubsub, response.category, category_updated: "*")
      # Absinthe.Subscription.publish(context.pubsub, response.category, category_updated: input.id)

      {:ok, format_category(response.category)}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to update category: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリを削除
  """
  def delete_category(_parent, %{id: id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %CategoryUpParam{
           crud: :DELETE,
           id: id
         },
         {:ok, _response} <- Proto.CategoryCommand.Stub.update_category(channel, request) do
      # 削除成功通知を送信
      # TODO: Add PubSub support
      # Absinthe.Subscription.publish(context.pubsub, id, category_deleted: "*")

      {:ok, true}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to delete category: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリに属する商品を取得（遅延読み込み）
  """
  def get_products(%{id: category_id}, _args, context) do
    # Product リゾルバーに委譲
    ClientService.GraphQL.Resolvers.ProductResolver.get_products_by_category(
      nil,
      %{category_id: category_id},
      context
    )
  end

  # プライベート関数

  defp build_category_query_request(id) do
    %CategoryQueryRequest{id: id}
  end

  defp execute_category_query(request) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         {:ok, response} <- Query.CategoryQuery.Stub.get_category(channel, request) do
      {:ok, response}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get category: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  defp handle_category_response({:ok, response}) do
    {:ok, format_category(response.category)}
  end

  defp handle_category_response({:error, reason}) do
    {:error, reason}
  end

  defp format_category(nil), do: nil

  defp format_category(category) do
    %{
      id: category.id,
      name: category.name,
      created_at: format_timestamp(category.created_at),
      updated_at: format_timestamp(category.updated_at)
    }
  end

  defp format_timestamp(nil), do: nil
  defp format_timestamp(0), do: nil

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end

  # Google.Protobuf.Timestamp 構造体の場合
  defp format_timestamp(%{seconds: seconds, nanos: _nanos}) when is_integer(seconds) do
    DateTime.from_unix!(seconds)
  end

  defp format_timestamp(%{__struct__: _} = struct) do
    # その他のstructは文字列表現を返す
    to_string(struct)
  end

  defp format_timestamp(other) do
    # その他の場合は文字列に変換
    to_string(other)
  end
end
