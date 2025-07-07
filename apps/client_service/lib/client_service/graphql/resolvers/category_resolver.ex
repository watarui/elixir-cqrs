defmodule ClientService.GraphQL.Resolvers.CategoryResolver do
  @moduledoc """
  カテゴリ用 GraphQL リゾルバー

  Command Service と Query Service への gRPC 通信を行います
  """

  alias ClientService.Application.CqrsFacade
  alias ClientService.GraphQL.BatchCache
  alias ClientService.Infrastructure.GrpcConnections
  require Logger

  alias Query.{
    CategoryByNameRequest,
    CategoryExistsRequest,
    CategoryPaginationRequest,
    CategorySearchRequest,
    Empty,
    ProductByCategoryRequest
  }

  @doc """
  IDでカテゴリを取得
  """
  @spec get_category(any(), %{id: String.t()}, any()) :: {:ok, map()} | {:error, String.t()}
  def get_category(_parent, %{id: id}, _context) do
    case CqrsFacade.query({:get_category, id}) do
      {:ok, category} ->
        {:ok, category}

      {:error, :not_found} ->
        {:error, "Category not found"}

      {:error, reason} ->
        Logger.error("Failed to get category: #{inspect(reason)}")
        {:error, "Failed to get category"}
    end
  end

  @doc """
  名前でカテゴリを取得
  """
  @spec get_category_by_name(any(), %{name: String.t()}, any()) ::
          {:ok, map()} | {:error, String.t()}
  def get_category_by_name(_parent, %{name: name}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %CategoryByNameRequest{name: name},
         {:ok, response} <- Query.CategoryQuery.Stub.get_category_by_name(channel, request) do
      {:ok, format_category(response.category)}
    else
      {:error, %GRPC.RPCError{} = error} ->
        {:error, "Failed to get category by name: #{error.message}"}

      %GRPC.RPCError{} = error ->
        {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  全カテゴリを取得
  """
  @spec list_categories(any(), any(), any()) :: {:ok, [map()]} | {:error, String.t()}
  def list_categories(_parent, _args, _context) do
    case CqrsFacade.query({:list_categories}) do
      {:ok, categories} ->
        {:ok, categories}

      {:error, reason} ->
        Logger.error("Failed to list categories: #{inspect(reason)}")
        {:error, "Failed to list categories"}
    end
  end

  @doc """
  カテゴリを検索
  """
  @spec search_categories(any(), %{search_term: String.t()}, any()) ::
          {:ok, [map()]} | {:error, String.t()}
  def search_categories(_parent, %{search_term: search_term}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %CategorySearchRequest{search_term: search_term},
         {:ok, response} <- Query.CategoryQuery.Stub.search_categories(channel, request) do
      categories = Enum.map(response.categories, &format_category/1)
      {:ok, categories}
    else
      {:error, %GRPC.RPCError{} = error} ->
        {:error, "Failed to search categories: #{error.message}"}

      %GRPC.RPCError{} = error ->
        {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  ページネーション付きカテゴリ一覧
  """
  @spec list_categories_paginated(any(), %{page: integer(), per_page: integer()}, any()) ::
          {:ok, [map()]} | {:error, String.t()}
  def list_categories_paginated(_parent, %{page: page, per_page: per_page}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %CategoryPaginationRequest{page: page, per_page: per_page},
         {:ok, response} <- Query.CategoryQuery.Stub.list_categories_paginated(channel, request) do
      categories = Enum.map(response.categories, &format_category/1)
      {:ok, categories}
    else
      {:error, %GRPC.RPCError{} = error} ->
        {:error, "Failed to get paginated categories: #{error.message}"}

      %GRPC.RPCError{} = error ->
        {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリ統計情報を取得
  """
  @spec get_statistics(any(), any(), any()) :: {:ok, map()} | {:error, String.t()}
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
      {:error, %GRPC.RPCError{} = error} ->
        {:error, "Failed to get category statistics: #{error.message}"}

      %GRPC.RPCError{} = error ->
        {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリ存在チェック
  """
  @spec category_exists(any(), %{id: String.t()}, any()) ::
          {:ok, boolean()} | {:error, String.t()}
  def category_exists(_parent, %{id: id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %CategoryExistsRequest{id: id},
         {:ok, response} <- Query.CategoryQuery.Stub.category_exists(channel, request) do
      {:ok, response.exists}
    else
      {:error, %GRPC.RPCError{} = error} ->
        {:error, "Failed to check category existence: #{error.message}"}

      %GRPC.RPCError{} = error ->
        {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリを作成
  """
  @spec create_category(any(), %{input: map()}, any()) :: {:ok, map()} | {:error, String.t()}
  def create_category(_parent, %{input: input}, _context) do
    case CqrsFacade.command({:create_category, input.name}) do
      {:ok, %{id: id}} ->
        # 作成したカテゴリの情報を取得して返す
        case CqrsFacade.query({:get_category, id}) do
          {:ok, category} ->
            {:ok, category}

          {:error, _} ->
            # カテゴリは作成されたが、取得に失敗した場合
            {:ok, %{id: id, name: input.name}}
        end

      {:error, reason} ->
        Logger.error("Failed to create category: #{inspect(reason)}")
        {:error, "Failed to create category: #{inspect(reason)}"}
    end
  end

  @doc """
  カテゴリを更新
  """
  @spec update_category(any(), %{input: map()}, any()) :: {:ok, map()} | {:error, String.t()}
  def update_category(_parent, %{input: input}, _context) do
    case CqrsFacade.command({:update_category, input.id, input.name}) do
      {:ok, _} ->
        # 更新したカテゴリの情報を取得して返す
        case CqrsFacade.query({:get_category, input.id}) do
          {:ok, category} ->
            {:ok, category}

          {:error, _} ->
            # カテゴリは更新されたが、取得に失敗した場合
            {:ok, %{id: input.id, name: input.name}}
        end

      {:error, reason} ->
        Logger.error("Failed to update category: #{inspect(reason)}")
        {:error, "Failed to update category: #{inspect(reason)}"}
    end
  end

  @doc """
  カテゴリを削除
  """
  @spec delete_category(any(), %{id: String.t()}, any()) ::
          {:ok, boolean()} | {:error, String.t()}
  def delete_category(_parent, %{id: id}, _context) do
    case CqrsFacade.command({:delete_category, id}) do
      {:ok, _} ->
        {:ok, true}

      {:error, reason} ->
        Logger.error("Failed to delete category: #{inspect(reason)}")
        {:error, "Failed to delete category: #{inspect(reason)}"}
    end
  end

  @doc """
  カテゴリに属する商品を取得（遅延読み込み）
  """
  @spec get_products(%{id: String.t()}, any(), any()) :: {:ok, [map()]} | {:error, String.t()}
  def get_products(%{id: category_id}, _args, _context) do
    BatchCache.get_products_by_category(category_id, fn ->
      # キャッシュミスの場合のみgRPC呼び出し
      with {:ok, channel} <- GrpcConnections.get_query_channel(),
           request <- %ProductByCategoryRequest{category_id: category_id},
           {:ok, response} <- Query.ProductQuery.Stub.get_products_by_category(channel, request) do
        products = Enum.map(response.products, &format_product/1)
        {:ok, products}
      else
        {:error, %GRPC.RPCError{} = error} ->
          {:error, "Failed to get products: #{error.message}"}

        error ->
          {:error, "Unexpected error: #{inspect(error)}"}
      end
    end)
  end

  # プライベート関数

  defp format_category(nil), do: nil

  defp format_category(category) do
    %{
      id: category.id,
      name: category.name,
      created_at: format_timestamp(Map.get(category, :created_at)),
      updated_at: format_timestamp(Map.get(category, :updated_at))
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

  defp format_product(nil), do: nil

  defp format_product(product) do
    %{
      id: product.id,
      name: product.name,
      price: product.price,
      category_id: Map.get(product, :category_id) || Map.get(product, :categoryId),
      created_at: format_timestamp(Map.get(product, :created_at)),
      updated_at: format_timestamp(Map.get(product, :updated_at))
    }
  end
end
