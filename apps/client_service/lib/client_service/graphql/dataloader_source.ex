defmodule ClientService.GraphQL.DataloaderSource do
  @moduledoc """
  GraphQL用のDataLoaderソース
  
  N+1クエリ問題を解決するため、バッチローディングを提供します。
  """
  
  alias ClientService.Infrastructure.GrpcConnections
  alias Query.{
    CategoryQueryRequest,
    ProductByCategoryRequest,
    Empty
  }
  
  @doc """
  カテゴリをバッチでロードします
  """
  @spec batch_load_categories([String.t()]) :: map()
  def batch_load_categories(category_ids) do
    with {:ok, channel} <- GrpcConnections.get_query_channel(),
         {:ok, %{categories: categories}} <- Query.CategoryQuery.Stub.list_categories(channel, %Empty{}) do
      # IDでカテゴリをマップ化
      categories
      |> Enum.filter(fn cat -> cat.id in category_ids end)
      |> Enum.map(fn cat -> {cat.id, format_category(cat)} end)
      |> Enum.into(%{})
    else
      _ -> %{}
    end
  end
  
  @doc """
  カテゴリIDで商品をバッチでロードします
  """
  @spec batch_load_products_by_category([String.t()]) :: map()
  def batch_load_products_by_category(category_ids) do
    with {:ok, channel} <- GrpcConnections.get_query_channel() do
      # 各カテゴリの商品を並列で取得
      tasks = 
        Enum.map(category_ids, fn category_id ->
          Task.async(fn ->
            case Query.ProductQuery.Stub.get_products_by_category(
              channel, 
              %ProductByCategoryRequest{category_id: category_id}
            ) do
              {:ok, %{products: products}} -> 
                {category_id, Enum.map(products, &format_product/1)}
              _ -> 
                {category_id, []}
            end
          end)
        end)
      
      # 結果を収集
      tasks
      |> Task.await_many(5000)
      |> Enum.into(%{})
    else
      _ -> %{}
    end
  end
  
  # フォーマット関数
  defp format_category(category) do
    %{
      id: category.id,
      name: category.name,
      created_at: format_timestamp(Map.get(category, :created_at)),
      updated_at: format_timestamp(Map.get(category, :updated_at))
    }
  end
  
  defp format_product(product) do
    %{
      id: product.id,
      name: product.name,
      price: product.price,
      category_id: if(product.category, do: product.category.id, else: nil),
      created_at: format_timestamp(Map.get(product, :created_at)),
      updated_at: format_timestamp(Map.get(product, :updated_at))
    }
  end
  
  defp format_timestamp(nil), do: nil
  defp format_timestamp(0), do: nil
  
  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end
  
  defp format_timestamp(%{seconds: seconds, nanos: _nanos}) when is_integer(seconds) do
    DateTime.from_unix!(seconds)
  end
  
  defp format_timestamp(%{__struct__: _} = struct) do
    to_string(struct)
  end
  
  defp format_timestamp(other) do
    to_string(other)
  end
end

defmodule ClientService.GraphQL.DataLoader do
  @moduledoc """
  DataLoader用のカスタムソース
  
  Dataloader.KVを使用してバッチローディングを実装します。
  """
  
  alias ClientService.GraphQL.DataloaderSource
  
  @doc """
  カテゴリローダーを作成
  """
  def new_category_loader do
    Dataloader.KV.new(&fetch_categories/2)
  end
  
  @doc """
  カテゴリ別商品ローダーを作成
  """
  def new_products_by_category_loader do
    Dataloader.KV.new(&fetch_products_by_category/2)
  end
  
  # バッチローディング関数（キーを親オブジェクトから取得）
  defp fetch_categories(_batch_key, products) do
    category_ids = products |> Map.values() |> Enum.map(& &1.category_id) |> Enum.uniq()
    results = DataloaderSource.batch_load_categories(category_ids)
    
    # 各商品のcategory_idをキーとして結果を返す
    Map.new(products, fn {key, product} ->
      {key, Map.get(results, product.category_id)}
    end)
  end
  
  defp fetch_products_by_category(_batch_key, categories) do
    category_ids = categories |> Map.values() |> Enum.map(& &1.id) |> Enum.uniq()
    results = DataloaderSource.batch_load_products_by_category(category_ids)
    
    # 各カテゴリのidをキーとして結果を返す
    Map.new(categories, fn {key, category} ->
      {key, Map.get(results, category.id, [])}
    end)
  end
end