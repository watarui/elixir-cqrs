defmodule CommandService.Infrastructure.UnitOfWork do
  @moduledoc """
  Command Service用のUnit of Work実装
  
  複数のドメイン操作を単一トランザクションで管理します。
  """
  
  @behaviour Shared.Infrastructure.UnitOfWork
  
  alias CommandService.Infrastructure.Database.Repo
  alias Shared.Infrastructure.UnitOfWork, as: BaseUoW
  
  @impl true
  def execute(operations) when is_function(operations) do
    BaseUoW.transact(Repo, operations)
  end
  
  @impl true
  def rollback(reason) do
    Repo.rollback(reason)
  end
  
  @doc """
  商品と在庫を同時に作成するトランザクション例
  """
  def create_product_with_stock(product, initial_stock \\ 0) do
    execute(fn ->
      alias CommandService.Infrastructure.Repositories.ProductRepository
      
      with {:ok, saved_product} <- ProductRepository.save(product),
           {:ok, _stock} <- create_initial_stock(saved_product, initial_stock) do
        {:ok, saved_product}
      end
    end)
  end
  
  @doc """
  カテゴリとその配下の商品を同時に更新
  """
  def update_category_with_products(category, product_updates) do
    execute(fn ->
      alias CommandService.Infrastructure.Repositories.{CategoryRepository, ProductRepository}
      
      with {:ok, updated_category} <- CategoryRepository.update(category),
           {:ok, updated_products} <- update_products_batch(product_updates, ProductRepository) do
        {:ok, {updated_category, updated_products}}
      end
    end)
  end
  
  # Private functions
  
  defp create_initial_stock(_product, _count) do
    # 在庫管理の実装（将来的に追加）
    {:ok, %{}}
  end
  
  defp update_products_batch(products, repository) do
    results = 
      Enum.reduce_while(products, {:ok, []}, fn product, {:ok, acc} ->
        case repository.update(product) do
          {:ok, updated} -> {:cont, {:ok, [updated | acc]}}
          error -> {:halt, error}
        end
      end)
    
    case results do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end
end