defmodule QueryService.Presentation.Grpc.ProductQueryServer do
  @moduledoc """
  商品クエリの gRPC サーバー実装
  """

  use GRPC.Server, service: ElixirCqrs.ProductQueryService.Service

  alias QueryService.Domain.Models.Product
  alias ElixirCqrs.Common.{Error, Timestamp}

  require Logger

  @doc """
  商品を取得
  """
  def get_product(request, _stream) do
    Logger.info("Getting product: #{request.id}")

    # TODO: リポジトリから取得
    # 仮実装
    case request.id do
      "not-found" ->
        %{
          product: nil,
          error: Error.new("NOT_FOUND", "Product not found")
        }

      id ->
        %{
          product: %{
            id: id,
            name: "Sample Product",
            price: "1000",
            currency: "JPY",
            category_id: "1",
            category_name: "電化製品",
            created_at: Timestamp.from_datetime(DateTime.utc_now()),
            updated_at: Timestamp.from_datetime(DateTime.utc_now())
          },
          error: nil
        }
    end
  end

  @doc """
  商品一覧を取得
  """
  def list_products(request, _stream) do
    Logger.info("Listing products")

    # TODO: リポジトリから取得
    # 仮実装
    products = [
      %{
        id: "1",
        name: "ノートパソコン",
        price: "120000",
        currency: "JPY",
        category_id: "1",
        category_name: "電化製品",
        created_at: Timestamp.from_datetime(DateTime.utc_now()),
        updated_at: Timestamp.from_datetime(DateTime.utc_now())
      },
      %{
        id: "2",
        name: "マウス",
        price: "3000",
        currency: "JPY",
        category_id: "1",
        category_name: "電化製品",
        created_at: Timestamp.from_datetime(DateTime.utc_now()),
        updated_at: Timestamp.from_datetime(DateTime.utc_now())
      }
    ]

    # フィルタリング（仮実装）
    filtered_products =
      if request.category_id do
        Enum.filter(products, fn p -> p.category_id == request.category_id end)
      else
        products
      end

    %{
      products: filtered_products,
      total_count: length(filtered_products),
      error: nil
    }
  end

  @doc """
  商品を検索
  """
  def search_products(request, _stream) do
    Logger.info("Searching products: #{request.search_term}")

    # TODO: リポジトリから検索
    # 仮実装
    %{
      products: [],
      total_count: 0,
      error: nil
    }
  end
end
