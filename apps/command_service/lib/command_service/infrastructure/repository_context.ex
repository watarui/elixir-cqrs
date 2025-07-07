defmodule CommandService.Infrastructure.RepositoryContext do
  @moduledoc """
  リポジトリの依存性注入コンテキスト
  
  テスト時にモックリポジトリを注入できるようにします。
  """
  
  @doc """
  商品リポジトリを取得
  
  環境変数やアプリケーション設定に基づいて適切な実装を返します。
  """
  @spec product_repository() :: module()
  def product_repository do
    Application.get_env(:command_service, :product_repository) ||
      CommandService.Infrastructure.Repositories.ProductRepository
  end
  
  @doc """
  カテゴリリポジトリを取得
  """
  @spec category_repository() :: module()
  def category_repository do
    Application.get_env(:command_service, :category_repository) ||
      CommandService.Infrastructure.Repositories.CategoryRepository
  end
  
  @doc """
  Unit of Work実装を取得
  """
  @spec unit_of_work() :: module()
  def unit_of_work do
    Application.get_env(:command_service, :unit_of_work) ||
      CommandService.Infrastructure.UnitOfWork
  end
  
  @doc """
  テスト用にリポジトリを設定
  
  ## 例
      setup do
        RepositoryContext.configure_for_test(
          product_repository: MockProductRepository,
          category_repository: MockCategoryRepository
        )
        
        on_exit(fn -> RepositoryContext.reset() end)
      end
  """
  @spec configure_for_test(keyword()) :: :ok
  def configure_for_test(opts) do
    Enum.each(opts, fn {key, value} ->
      Application.put_env(:command_service, key, value)
    end)
  end
  
  @doc """
  設定をリセット
  """
  @spec reset() :: :ok
  def reset do
    Application.delete_env(:command_service, :product_repository)
    Application.delete_env(:command_service, :category_repository)
    Application.delete_env(:command_service, :unit_of_work)
    :ok
  end
end