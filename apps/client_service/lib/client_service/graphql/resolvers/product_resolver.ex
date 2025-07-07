defmodule ClientService.GraphQL.Resolvers.ProductResolver do
  @moduledoc """
  商品用 GraphQL リゾルバー

  Command Service と Query Service への gRPC 通信を行います
  """

  alias ClientService.Infrastructure.GrpcConnections
  alias Shared.Infrastructure.Grpc.ResilientClient

  alias Query.{
    ProductQueryRequest,
    ProductByNameRequest,
    ProductSearchRequest,
    ProductByCategoryRequest,
    ProductPriceRangeRequest,
    ProductPaginationRequest,
    ProductExistsRequest,
    CategoryQueryRequest,
    Empty
  }

  alias Proto.ProductUpParam

  @doc """
  IDで商品を取得
  """
  @spec get_product(any(), %{id: String.t()}, any()) :: {:ok, map()} | {:error, String.t()}
  def get_product(_parent, %{id: id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductQueryRequest{id: id},
         {:ok, response} <- ResilientClient.call(
           fn -> Query.ProductQuery.Stub.get_product(channel, request) end,
           %{
             timeout: 3000,
             retry: %{max_attempts: 3},
             circuit_breaker: :query_service_cb,
             metadata: %{operation: "get_product", product_id: id}
           }
         ) do
      {:ok, format_product(response.product)}
    else
      {:error, :circuit_open} -> {:error, "Service temporarily unavailable"}
      {:error, :timeout} -> {:error, "Request timed out"}
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get product: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  名前で商品を取得
  """
  @spec get_product_by_name(any(), %{name: String.t()}, any()) :: {:ok, map()} | {:error, String.t()}
  def get_product_by_name(_parent, %{name: name}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductByNameRequest{name: name},
         {:ok, response} <- Query.ProductQuery.Stub.get_product_by_name(channel, request) do
      {:ok, format_product(response.product)}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get product by name: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  全商品を取得
  """
  @spec list_products(any(), any(), any()) :: {:ok, [map()]} | {:error, String.t()}
  def list_products(_parent, _args, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %Empty{},
         {:ok, response} <- ResilientClient.call(
           fn -> Query.ProductQuery.Stub.list_products(channel, request) end,
           %{
             timeout: 5000,
             retry: %{max_attempts: 2},
             circuit_breaker: :query_service_cb,
             metadata: %{operation: "list_products"}
           }
         ) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, :circuit_open} -> {:error, "Service temporarily unavailable"}
      {:error, :timeout} -> {:error, "Request timed out"}
      {:error, reason} -> {:error, "Failed to get products: #{inspect(reason)}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品を検索
  """
  @spec search_products(any(), %{search_term: String.t()}, any()) :: {:ok, [map()]} | {:error, String.t()}
  def search_products(_parent, %{search_term: search_term}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductSearchRequest{search_term: search_term},
         {:ok, response} <- Query.ProductQuery.Stub.search_products(channel, request) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to search products: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  ページネーション付き商品一覧
  """
  @spec list_products_paginated(any(), %{page: integer(), per_page: integer()}, any()) :: {:ok, map()} | {:error, String.t()}
  def list_products_paginated(_parent, %{page: page, per_page: per_page}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductPaginationRequest{page: page, per_page: per_page},
         {:ok, response} <- Query.ProductQuery.Stub.list_products_paginated(channel, request) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get paginated products: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリ別商品一覧
  """
  @spec get_products_by_category(any(), %{category_id: String.t()}, any()) :: {:ok, [map()]} | {:error, String.t()}
  def get_products_by_category(_parent, %{category_id: category_id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductByCategoryRequest{category_id: category_id},
         {:ok, response} <- Query.ProductQuery.Stub.get_products_by_category(channel, request) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get products by category: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  価格範囲で商品を検索
  """
  @spec get_products_by_price_range(any(), %{min_price: float(), max_price: float()}, any()) :: {:ok, [map()]} | {:error, String.t()}
  def get_products_by_price_range(
        _parent,
        %{min_price: min_price, max_price: max_price},
        _context
      ) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductPriceRangeRequest{min_price: min_price, max_price: max_price},
         {:ok, response} <- Query.ProductQuery.Stub.get_products_by_price_range(channel, request) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get products by price range: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品統計情報を取得
  """
  @spec get_statistics(any(), any(), any()) :: {:ok, map()} | {:error, String.t()}
  def get_statistics(_parent, _args, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %Empty{},
         {:ok, response} <- Query.ProductQuery.Stub.get_product_statistics(channel, request) do
      statistics = %{
        total_count: response.total_count,
        has_products: response.has_products,
        average_price: response.average_price,
        total_value: response.total_value,
        products_with_timestamps: response.products_with_timestamps
      }

      {:ok, statistics}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to get product statistics: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品存在チェック
  """
  @spec product_exists(any(), %{id: String.t()}, any()) :: {:ok, boolean()} | {:error, String.t()}
  def product_exists(_parent, %{id: id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductExistsRequest{id: id},
         {:ok, response} <- Query.ProductQuery.Stub.product_exists(channel, request) do
      {:ok, response.exists}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to check product existence: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品を作成
  """
  @spec create_product(any(), %{input: map()}, any()) :: {:ok, map()} | {:error, String.t()}
  def create_product(_parent, %{input: input}, _context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %ProductUpParam{
           crud: :INSERT,
           name: input.name,
           price: round(input.price),
           categoryId: input.category_id
         },
         {:ok, response} <- ResilientClient.call(
           fn -> Proto.ProductCommand.Stub.update_product(channel, request) end,
           %{
             timeout: 5000,
             retry: %{max_attempts: 3},
             circuit_breaker: :command_service_cb,
             metadata: %{operation: "create_product", name: input.name}
           }
         ) do
      # 作成成功通知を送信
      # TODO: Add PubSub support
      # Absinthe.Subscription.publish(context.pubsub, response.product, product_created: "*")

      case response do
        %{product: nil, error: %{message: message}} ->
          {:error, message}
        %{product: product} when not is_nil(product) ->
          # Commandサービスからの応答にはcategory_idが含まれないため、inputから補完
          formatted = format_product(product)
          formatted_with_category_id = Map.put(formatted, :category_id, input.category_id)
          {:ok, formatted_with_category_id}
        _ ->
          {:error, "Unexpected response format"}
      end
    else
      {:error, :circuit_open} -> {:error, "Service temporarily unavailable"}
      {:error, :timeout} -> {:error, "Request timed out"}
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to create product: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品を更新
  """
  @spec update_product(any(), %{input: map()}, any()) :: {:ok, map()} | {:error, String.t()}
  def update_product(_parent, %{input: input}, _context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %ProductUpParam{
           crud: :UPDATE,
           id: input.id,
           name: Map.get(input, :name),
           price: if(Map.has_key?(input, :price) && input.price, do: round(input.price), else: nil),
           categoryId: Map.get(input, :category_id)
         },
         {:ok, response} <- Proto.ProductCommand.Stub.update_product(channel, request) do
      # 更新成功通知を送信
      # TODO: Add PubSub support
      # Absinthe.Subscription.publish(context.pubsub, response.product, product_updated: "*")
      # Absinthe.Subscription.publish(context.pubsub, response.product, product_updated: input.id)

      {:ok, format_product(response.product)}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to update product: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品を削除
  """
  @spec delete_product(any(), %{id: String.t()}, any()) :: {:ok, boolean()} | {:error, String.t()}
  def delete_product(_parent, %{id: id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %ProductUpParam{
           crud: :DELETE,
           id: id
         },
         {:ok, _response} <- Proto.ProductCommand.Stub.update_product(channel, request) do
      # 削除成功通知を送信
      # TODO: Add PubSub support
      # Absinthe.Subscription.publish(context.pubsub, id, product_deleted: "*")

      {:ok, true}
    else
      {:error, %GRPC.RPCError{} = error} -> {:error, "Failed to delete product: #{error.message}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品が属するカテゴリを取得（遅延読み込み、キャッシュ使用）
  """
  @spec get_category(%{category_id: String.t()}, any(), any()) :: {:ok, map()} | {:error, String.t()}
  def get_category(%{category_id: category_id}, _args, _context) do
    ClientService.GraphQL.BatchCache.get_category(category_id, fn ->
      # キャッシュミスの場合のみgRPC呼び出し
      with {:ok, channel} <- GrpcConnections.get_query_channel(),
           request <- %CategoryQueryRequest{id: category_id},
           {:ok, response} <- ResilientClient.call(
             fn -> Query.CategoryQuery.Stub.get_category(channel, request) end,
             %{
               timeout: 2000,
               retry: %{max_attempts: 2},
               circuit_breaker: :query_service_cb,
               metadata: %{operation: "get_category", category_id: category_id}
             }
           ) do
        {:ok, format_category(response.category)}
      else
        {:error, :circuit_open} -> {:error, "Service temporarily unavailable"}
        {:error, :timeout} -> {:error, "Request timed out"}
        {:error, %GRPC.RPCError{status: :not_found}} -> 
          {:error, "Category not found"}
        {:error, %GRPC.RPCError{} = error} -> 
          {:error, "Failed to get category: #{error.message}"}
        error -> 
          {:error, "Unexpected error: #{inspect(error)}"}
      end
    end)
  end

  # プライベート関数

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
  
  defp format_category(nil), do: nil
  
  defp format_category(category) do
    %{
      id: category.id,
      name: category.name,
      created_at: format_timestamp(Map.get(category, :created_at)),
      updated_at: format_timestamp(Map.get(category, :updated_at))
    }
  end
end
