defmodule ClientService.GraphQL.Resolvers.ProductResolver do
  @moduledoc """
  商品関連の GraphQL リゾルバー
  """

  alias ClientService.Infrastructure.GrpcConnections
  # TODO: gRPC クライアントスタブ
  # alias Shared.Proto.ProductCommand
  # alias Shared.Proto.ProductQuery

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
    # TODO: Query Service への gRPC 呼び出し
    {:ok,
     [
       %{
         id: "1",
         name: "ノートパソコン",
         price: Decimal.new("120000"),
         currency: "JPY",
         category_id: "1",
         created_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
       },
       %{
         id: "2",
         name: "マウス",
         price: Decimal.new("3000"),
         currency: "JPY",
         category_id: "1",
         created_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
       }
     ]}
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
    # TODO: Command Service への gRPC 呼び出し
    {:ok,
     %{
       id: UUID.uuid4(),
       name: input.name,
       price: input.price,
       currency: "JPY",
       category_id: input.category_id,
       created_at: DateTime.utc_now(),
       updated_at: DateTime.utc_now()
     }}
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
