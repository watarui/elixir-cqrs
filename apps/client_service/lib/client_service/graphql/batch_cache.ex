defmodule ClientService.GraphQL.BatchCache do
  @moduledoc """
  N+1問題を解決するためのバッチキャッシュ
  
  同一リクエスト内でのデータ重複取得を防ぎます。
  """
  
  use Agent
  
  @doc """
  キャッシュプロセスを開始
  """
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end
  
  @doc """
  カテゴリをキャッシュから取得、なければ取得してキャッシュ
  """
  def get_category(id, fetcher_fn) do
    cache_key = {:category, id}
    
    case get(cache_key) do
      nil ->
        case fetcher_fn.() do
          {:ok, category} = result ->
            put(cache_key, category)
            result
          error ->
            error
        end
      
      category ->
        {:ok, category}
    end
  end
  
  @doc """
  商品リストをキャッシュから取得
  """
  def get_products_by_category(category_id, fetcher_fn) do
    cache_key = {:products_by_category, category_id}
    
    case get(cache_key) do
      nil ->
        case fetcher_fn.() do
          {:ok, products} = result ->
            put(cache_key, products)
            result
          error ->
            error
        end
      
      products ->
        {:ok, products}
    end
  end
  
  @doc """
  キャッシュをクリア（リクエスト終了時）
  """
  def clear do
    Agent.update(__MODULE__, fn _ -> %{} end)
  end
  
  # Private functions
  
  defp get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  catch
    :exit, _ -> nil
  end
  
  defp put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  catch
    :exit, _ -> :ok
  end
end