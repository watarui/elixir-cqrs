defmodule ClientService.GraphQL.Resolvers.ProductResolverPubsub do
  @moduledoc """
  商品関連の GraphQL リゾルバー (PubSub版)
  """

  alias ClientService.Infrastructure.{RemoteCommandBus, RemoteQueryBus}
  alias QueryService.Application.Queries.ProductQueries
  alias CommandService.Application.Commands.ProductCommands

  require Logger

  @doc """
  商品を取得
  """
  def get_product(_parent, %{id: id}, _resolution) do
    query = %ProductQueries.GetProduct{id: id}

    case RemoteQueryBus.send_query(query) do
      {:ok, product} ->
        {:ok, transform_product(product)}

      {:error, reason} ->
        Logger.error("Failed to get product: #{inspect(reason)}")
        {:error, "Product not found"}
    end
  end

  @doc """
  商品一覧を取得
  """
  def list_products(_parent, args, _resolution) do
    # ページ番号から offset を計算
    page = Map.get(args, :page, 1)
    page_size = Map.get(args, :page_size, 20)
    offset = (page - 1) * page_size

    query = %ProductQueries.ListProducts{
      limit: page_size,
      offset: offset
    }

    case RemoteQueryBus.send_query(query) do
      {:ok, products} ->
        {:ok, Enum.map(products, &transform_product/1)}

      {:error, reason} ->
        Logger.error("Failed to list products: #{inspect(reason)}")
        {:ok, []}
    end
  end

  @doc """
  カテゴリ別に商品を取得
  """
  def list_products_by_category(_parent, %{category_id: category_id} = args, _resolution) do
    page = Map.get(args, :page, 1)
    page_size = Map.get(args, :page_size, 20)
    offset = (page - 1) * page_size

    query = %ProductQueries.ListProducts{
      category_id: category_id,
      limit: page_size,
      offset: offset
    }

    case RemoteQueryBus.send_query(query) do
      {:ok, products} ->
        {:ok, Enum.map(products, &transform_product/1)}

      {:error, reason} ->
        Logger.error("Failed to list products by category: #{inspect(reason)}")
        {:ok, []}
    end
  end

  @doc """
  商品を検索
  """
  def search_products(_parent, %{search_term: search_term} = args, _resolution) do
    page = Map.get(args, :page, 1)
    page_size = Map.get(args, :page_size, 20)
    offset = (page - 1) * page_size

    query = %ProductQueries.SearchProducts{
      search_term: search_term,
      limit: page_size,
      offset: offset
    }

    case RemoteQueryBus.send_query(query) do
      {:ok, products} ->
        {:ok, Enum.map(products, &transform_product/1)}

      {:error, reason} ->
        Logger.error("Failed to search products: #{inspect(reason)}")
        {:ok, []}
    end
  end

  @doc """
  商品を作成
  """
  def create_product(_parent, %{input: input}, _resolution) do
    command = %ProductCommands.CreateProduct{
      name: input.name,
      description: Map.get(input, :description, ""),
      price: input.price,
      stock_quantity: input.stock_quantity,
      category_id: input.category_id
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, aggregate} ->
        {:ok,
         %{
           id: aggregate.id.value,
           name: aggregate.name.value,
           description: aggregate.description,
           price: aggregate.price.amount,
           stock_quantity: aggregate.stock_quantity,
           category_id: aggregate.category_id && aggregate.category_id.value,
           created_at: aggregate.created_at,
           updated_at: aggregate.updated_at
         }}

      {:error, reason} ->
        Logger.error("Failed to create product: #{inspect(reason)}")
        {:error, "Failed to create product: #{inspect(reason)}"}
    end
  end

  @doc """
  商品を更新
  """
  def update_product(_parent, %{id: id, input: input}, _resolution) do
    command = %ProductCommands.UpdateProduct{
      id: id,
      name: input.name,
      description: Map.get(input, :description),
      price: Map.get(input, :price),
      stock_quantity: Map.get(input, :stock_quantity),
      category_id: Map.get(input, :category_id)
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, aggregate} ->
        {:ok,
         %{
           id: aggregate.id.value,
           name: aggregate.name.value,
           description: aggregate.description,
           price: aggregate.price.amount,
           stock_quantity: aggregate.stock_quantity,
           category_id: aggregate.category_id && aggregate.category_id.value,
           created_at: aggregate.created_at,
           updated_at: aggregate.updated_at
         }}

      {:error, reason} ->
        Logger.error("Failed to update product: #{inspect(reason)}")
        {:error, "Failed to update product: #{inspect(reason)}"}
    end
  end

  @doc """
  商品を削除
  """
  def delete_product(_parent, %{id: id}, _resolution) do
    command = %ProductCommands.DeleteProduct{id: id}

    case RemoteCommandBus.send_command(command) do
      {:ok, _} ->
        {:ok, %{success: true, message: "Product deleted successfully"}}

      {:error, reason} ->
        Logger.error("Failed to delete product: #{inspect(reason)}")
        {:error, "Failed to delete product: #{inspect(reason)}"}
    end
  end

  @doc """
  在庫を更新
  """
  def update_stock(_parent, %{id: id, quantity: quantity}, _resolution) do
    command = %ProductCommands.UpdateStock{
      id: id,
      quantity: quantity
    }

    case RemoteCommandBus.send_command(command) do
      {:ok, aggregate} ->
        {:ok,
         %{
           id: aggregate.id.value,
           stock_quantity: aggregate.stock_quantity
         }}

      {:error, reason} ->
        Logger.error("Failed to update stock: #{inspect(reason)}")
        {:error, "Failed to update stock: #{inspect(reason)}"}
    end
  end

  # プライベート関数

  defp transform_product(product) do
    %{
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      stock_quantity: product.stock_quantity,
      category_id: product.category_id,
      category_name: product.category_name,
      created_at: product.created_at,
      updated_at: product.updated_at
    }
  end
end
