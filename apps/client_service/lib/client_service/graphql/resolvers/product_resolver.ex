defmodule ClientService.GraphQL.Resolvers.ProductResolver do
  @moduledoc """
  商品用 GraphQL リゾルバー

  Command Service と Query Service への gRPC 通信を行います
  """

  alias ClientService.Infrastructure.GrpcConnections

  alias Query.{
    ProductQueryRequest,
    ProductByNameRequest,
    ProductSearchRequest,
    ProductByCategoryRequest,
    ProductPriceRangeRequest,
    ProductPaginationRequest,
    ProductExistsRequest
  }

  alias Proto.ProductUpParam

  @doc """
  IDで商品を取得
  """
  def get_product(_parent, %{id: id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductQueryRequest{id: id},
         {:ok, response} <- Query.ProductQuery.Stub.get_product(channel, request) do
      {:ok, format_product(response.product)}
    else
      {:error, reason} -> {:error, "Failed to get product: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  名前で商品を取得
  """
  def get_product_by_name(_parent, %{name: name}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductByNameRequest{name: name},
         {:ok, response} <- Query.ProductQuery.Stub.get_product_by_name(channel, request) do
      {:ok, format_product(response.product)}
    else
      {:error, reason} -> {:error, "Failed to get product by name: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  全商品を取得
  """
  def list_products(_parent, _args, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %{},
         {:ok, response} <- Query.ProductQuery.Stub.list_products(channel, request) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, reason} -> {:error, "Failed to list products: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品を検索
  """
  def search_products(_parent, %{search_term: search_term}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductSearchRequest{search_term: search_term},
         {:ok, response} <- Query.ProductQuery.Stub.search_products(channel, request) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, reason} -> {:error, "Failed to search products: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  ページネーション付き商品一覧
  """
  def list_products_paginated(_parent, %{page: page, per_page: per_page}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductPaginationRequest{page: page, per_page: per_page},
         {:ok, response} <- Query.ProductQuery.Stub.list_products_paginated(channel, request) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, reason} -> {:error, "Failed to get paginated products: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  カテゴリ別商品一覧
  """
  def get_products_by_category(_parent, %{category_id: category_id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductByCategoryRequest{category_id: category_id},
         {:ok, response} <- Query.ProductQuery.Stub.get_products_by_category(channel, request) do
      products = Enum.map(response.products, &format_product/1)
      {:ok, products}
    else
      {:error, reason} -> {:error, "Failed to get products by category: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  価格範囲で商品を検索
  """
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
      {:error, reason} -> {:error, "Failed to get products by price range: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品統計情報を取得
  """
  def get_statistics(_parent, _args, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %{},
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
      {:error, reason} -> {:error, "Failed to get product statistics: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品存在チェック
  """
  def product_exists(_parent, %{id: id}, _context) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         request <- %ProductExistsRequest{id: id},
         {:ok, response} <- Query.ProductQuery.Stub.product_exists(channel, request) do
      {:ok, response.exists}
    else
      {:error, reason} -> {:error, "Failed to check product existence: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品を作成
  """
  def create_product(_parent, %{input: input}, context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %ProductUpParam{
           crud: :INSERT,
           name: input.name,
           price: input.price,
           categoryId: input.category_id
         },
         {:ok, response} <- Proto.ProductCommand.Stub.update_product(channel, request) do
      # 作成成功通知を送信
      Absinthe.Subscription.publish(context.pubsub, response.product, product_created: "*")

      {:ok, format_product(response.product)}
    else
      {:error, reason} -> {:error, "Failed to create product: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品を更新
  """
  def update_product(_parent, %{input: input}, context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %ProductUpParam{
           crud: :UPDATE,
           id: input.id,
           name: input.name,
           price: input.price,
           categoryId: input.category_id
         },
         {:ok, response} <- Proto.ProductCommand.Stub.update_product(channel, request) do
      # 更新成功通知を送信
      Absinthe.Subscription.publish(context.pubsub, response.product, product_updated: "*")
      Absinthe.Subscription.publish(context.pubsub, response.product, product_updated: input.id)

      {:ok, format_product(response.product)}
    else
      {:error, reason} -> {:error, "Failed to update product: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品を削除
  """
  def delete_product(_parent, %{id: id}, context) do
    with {:ok, channel} <- GrpcConnections.get_command_channel(),
         request <- %ProductUpParam{
           crud: :DELETE,
           id: id
         },
         {:ok, _response} <- Proto.ProductCommand.Stub.update_product(channel, request) do
      # 削除成功通知を送信
      Absinthe.Subscription.publish(context.pubsub, id, product_deleted: "*")

      {:ok, true}
    else
      {:error, reason} -> {:error, "Failed to delete product: #{reason}"}
      %GRPC.RPCError{} = error -> {:error, "gRPC error: #{error.message}"}
    end
  end

  @doc """
  商品が属するカテゴリを取得（遅延読み込み）
  """
  def get_category(%{category_id: category_id}, _args, context) do
    # Category リゾルバーに委譲
    ClientService.GraphQL.Resolvers.CategoryResolver.get_category(
      nil,
      %{id: category_id},
      context
    )
  end

  # プライベート関数

  defp format_product(nil), do: nil

  defp format_product(product) do
    %{
      id: product.id,
      name: product.name,
      price: product.price,
      category_id: product.category_id,
      created_at: format_timestamp(product.created_at),
      updated_at: format_timestamp(product.updated_at)
    }
  end

  defp format_timestamp(0), do: nil

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end

  defp format_timestamp(_), do: nil
end
