defmodule Shared.Infrastructure.UnitOfWork do
  @moduledoc """
  Unit of Workパターンの実装
  
  複数のリポジトリ操作を単一のトランザクションで管理します。
  """
  
  alias Shared.Errors.AppError
  
  @doc """
  Unit of Workのビヘイビア定義
  """
  @callback execute(function()) :: {:ok, any()} | {:error, AppError.t()}
  @callback rollback(reason :: any()) :: :ok
  
  @doc """
  トランザクション内で複数の操作を実行
  
  ## パラメータ
    - repo_module: Ecto.Repoモジュール
    - operations: 実行する操作の関数
  
  ## 例
      UnitOfWork.transact(Repo, fn ->
        with {:ok, product} <- ProductRepository.save(product),
             {:ok, category} <- CategoryRepository.update(category) do
          {:ok, {product, category}}
        end
      end)
  """
  @spec transact(module(), function()) :: {:ok, any()} | {:error, AppError.t()}
  def transact(repo_module, operations) when is_atom(repo_module) and is_function(operations) do
    case repo_module.transaction(fn ->
      case operations.() do
        {:ok, result} -> result
        {:error, _} = error -> repo_module.rollback(error)
        error -> repo_module.rollback({:error, error})
      end
    end) do
      {:ok, result} -> 
        {:ok, result}
      
      {:error, {:error, %AppError{} = error}} -> 
        {:error, error}
      
      {:error, error} -> 
        {:error, AppError.infrastructure_error("Transaction failed", %{error: inspect(error)})}
    end
  rescue
    error ->
      {:error, AppError.infrastructure_error("Transaction failed with exception", %{
        error: inspect(error),
        stacktrace: inspect(__STACKTRACE__)
      })}
  end
  
  @doc """
  複数のリポジトリ操作を順次実行
  
  ## パラメータ
    - repo_module: Ecto.Repoモジュール  
    - operations: {リポジトリモジュール, 関数名, 引数}のリスト
  
  ## 例
      UnitOfWork.execute_all(Repo, [
        {ProductRepository, :save, [product]},
        {CategoryRepository, :update, [category]}
      ])
  """
  @spec execute_all(module(), list()) :: {:ok, list()} | {:error, AppError.t()}
  def execute_all(repo_module, operations) when is_list(operations) do
    transact(repo_module, fn ->
      results = 
        Enum.reduce_while(operations, {:ok, []}, fn {module, function, args}, {:ok, acc} ->
          case apply(module, function, args) do
            {:ok, result} -> {:cont, {:ok, [result | acc]}}
            {:error, _} = error -> {:halt, error}
            :ok -> {:cont, {:ok, [:ok | acc]}}
          end
        end)
      
      case results do
        {:ok, list} -> {:ok, Enum.reverse(list)}
        error -> error
      end
    end)
  end
  
  @doc """
  複数の操作を並列実行（読み取り専用）
  
  ## パラメータ
    - operations: 実行する操作のリスト
  
  ## 例
      UnitOfWork.execute_parallel([
        fn -> ProductRepository.find_by_id(id1) end,
        fn -> CategoryRepository.find_by_id(id2) end
      ])
  """
  @spec execute_parallel(list(function())) :: {:ok, list()} | {:error, AppError.t()}
  def execute_parallel(operations) when is_list(operations) do
    tasks = Enum.map(operations, &Task.async/1)
    
    results = 
      tasks
      |> Task.await_many(5000)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, result}, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
        {:error, _} = error, _ -> {:halt, error}
        result, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
      end)
    
    case results do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  rescue
    error ->
      {:error, AppError.infrastructure_error("Parallel execution failed", %{
        error: inspect(error)
      })}
  end
end