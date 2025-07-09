defmodule ClientService.GraphQL.Resolvers.ProductResolver do
  @moduledoc """
  商品関連の GraphQL リゾルバー
  """

  alias ClientService.Infrastructure.GrpcConnections
  alias ElixirCqrs.ProductCommandService.Stub, as: ProductCommandStub
  alias ElixirCqrs.ProductQueryService.Stub, as: ProductQueryStub

  require Logger

  @doc """
  商品を取得
  """
  def get_product(_parent, %{id: id}, _resolution) do
    # TODO: Query Service への gRPC 呼び出し
    {:ok,
     %{
       id: id,
       name: "Sample Product",
       price: Decimal.new("1000"),
       currency: "JPY",
       category_id: "1",
       created_at: DateTime.utc_now(),
       updated_at: DateTime.utc_now()
     }}
  end

  @doc """
  商品一覧を取得
  """
  def list_products(_parent, args, _resolution) do
    case GrpcConnections.get_query_channel() do
      nil ->
        {:error, "Query Service unavailable"}

      channel ->
        # ページ番号から offset を計算
        page = Map.get(args, :page, 1)
        page_size = Map.get(args, :page_size, 20)
        offset = (page - 1) * page_size

        request = %ElixirCqrs.ListProductsRequest{
          pagination: %ElixirCqrs.Pagination{
            limit: page_size,
            offset: offset
          },
          category_id: Map.get(args, :category_id, "")
        }

        case ProductQueryStub.list_products(channel, request) do
          {:ok, response} ->
            products =
              Enum.map(response.products, fn prod ->
                %{
                  id: prod.id,
                  name: prod.name,
                  description: prod.description,
                  price: Decimal.new(prod.price || "0"),
                  stock_quantity: prod.stock_quantity || 0,
                  currency: "JPY",
                  category_id: prod.category_id,
                  created_at: DateTime.from_unix!(prod.created_at || 0),
                  updated_at: DateTime.from_unix!(prod.updated_at || 0)
                }
              end)

            {:ok, products}

          {:error, reason} ->
            Logger.error("Failed to list products: #{inspect(reason)}")
            {:ok, []}
        end
    end
  end

  @doc """
  商品を検索
  """
  def search_products(_parent, %{search_term: search_term} = args, _resolution) do
    # TODO: Query Service への gRPC 呼び出し
    {:ok, []}
  end

  @doc """
  商品を作成
  """
  def create_product(_parent, %{input: input}, _resolution) do
    case GrpcConnections.get_command_channel() do
      nil ->
        {:error, "Command Service unavailable"}

      channel ->
        # 価格を Money 型に変換
        # dollars to cents
        price_amount = trunc(input.price * 100)

        request = %ElixirCqrs.CreateProductRequest{
          name: input.name,
          description: Map.get(input, :description, ""),
          price: %ElixirCqrs.Money{
            amount: price_amount,
            currency: "USD"
          },
          initial_stock: Map.get(input, :stock_quantity, 0),
          category_id: input.category_id
        }

        case ProductCommandStub.create_product(channel, request) do
          {:ok, response} ->
            if response.id && response.id != "" do
              # 成功時は product フィールドから情報を取得
              product = response.product

              {:ok,
               %{
                 id: product.id,
                 name: product.name,
                 description: product.description,
                 # cents to dollars
                 price: product.price.amount / 100.0,
                 stock_quantity: product.stock_quantity,
                 currency: product.price.currency,
                 category_id: product.category_id,
                 created_at: ElixirCqrs.Common.Timestamp.to_datetime(product.created_at),
                 updated_at: ElixirCqrs.Common.Timestamp.to_datetime(product.updated_at)
               }}
            else
              {:error, "Failed to create product"}
            end

          {:error, reason} ->
            Logger.error("Failed to create product: #{inspect(reason)}")
            {:error, "Failed to create product"}
        end
    end
  end

  @doc """
  商品を更新
  """
  def update_product(_parent, %{id: id, input: input}, _resolution) do
    # TODO: Command Service への gRPC 呼び出し
    # 現在の値とマージ
    {:ok,
     %{
       id: id,
       name: input[:name] || "Updated Product",
       price: input[:price] || Decimal.new("1000"),
       currency: "JPY",
       category_id: input[:category_id] || "1",
       created_at: DateTime.utc_now(),
       updated_at: DateTime.utc_now()
     }}
  end

  @doc """
  商品価格を変更
  """
  def change_product_price(_parent, %{id: id, new_price: new_price}, _resolution) do
    # TODO: Command Service への gRPC 呼び出し
    {:ok,
     %{
       id: id,
       name: "Product",
       price: new_price,
       currency: "JPY",
       category_id: "1",
       created_at: DateTime.utc_now(),
       updated_at: DateTime.utc_now()
     }}
  end

  @doc """
  商品を削除
  """
  def delete_product(_parent, %{id: id}, _resolution) do
    # TODO: Command Service への gRPC 呼び出し
    {:ok, %{success: true, message: "Product deleted successfully"}}
  end
end
