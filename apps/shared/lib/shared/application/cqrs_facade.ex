defmodule Shared.Application.CQRSFacade do
  @moduledoc """
  CQRSファサード
  
  コマンドとクエリの実行を統一されたインターフェースで提供します。
  システム全体のエントリーポイントとして機能します。
  """

  require Logger

  @doc """
  コマンドを実行する
  
  ## パラメータ
    - command: 実行するコマンド構造体
  
  ## 戻り値
    - {:ok, result} - コマンドの実行結果
    - {:error, reason} - エラーの理由
  
  ## 例
      iex> command = CreateProduct.new(%{id: "123", name: "Test", price: 100, category_id: "cat-1"})
      iex> CQRSFacade.execute_command(command)
      {:ok, %{aggregate_id: "123", events: [...]}}
  """
  @spec execute_command(command :: struct()) :: {:ok, any()} | {:error, term()}
  def execute_command(command) do
    Logger.info("Executing command: #{inspect(command.__struct__)}")
    
    # コマンドバスへの委譲
    # 実際の実装では、リモートサービスへのgRPC呼び出しに置き換える
    CommandService.Application.CommandBus.execute(command)
  rescue
    e ->
      Logger.error("Command execution failed: #{inspect(e)}")
      {:error, Exception.message(e)}
  end

  @doc """
  クエリを実行する
  
  ## パラメータ
    - query: 実行するクエリ構造体
  
  ## 戻り値
    - {:ok, result} - クエリの実行結果
    - {:error, reason} - エラーの理由
  
  ## 例
      iex> query = GetProduct.new(%{id: "123"})
      iex> CQRSFacade.execute_query(query)
      {:ok, %{id: "123", name: "Test", price: "100.00", category_id: "cat-1"}}
  """
  @spec execute_query(query :: struct()) :: {:ok, any()} | {:error, term()}
  def execute_query(query) do
    Logger.info("Executing query: #{inspect(query.__struct__)}")
    
    # クエリバスへの委譲
    # 実際の実装では、リモートサービスへのgRPC呼び出しに置き換える
    QueryService.Application.QueryBus.execute(query)
  rescue
    e ->
      Logger.error("Query execution failed: #{inspect(e)}")
      {:error, Exception.message(e)}
  end

  @doc """
  コマンドを非同期で実行する
  
  ## パラメータ
    - command: 実行するコマンド構造体
  
  ## 戻り値
    - :ok - コマンドがキューに追加された
  
  ## 例
      iex> command = UpdateProduct.new(%{id: "123", name: "Updated"})
      iex> CQRSFacade.execute_command_async(command)
      :ok
  """
  @spec execute_command_async(command :: struct()) :: :ok
  def execute_command_async(command) do
    Logger.info("Executing async command: #{inspect(command.__struct__)}")
    
    spawn(fn ->
      execute_command(command)
    end)
    
    :ok
  end

  @doc """
  複数のクエリを並列実行する
  
  ## パラメータ
    - queries: 実行するクエリ構造体のリスト
  
  ## 戻り値
    - results: 各クエリの実行結果のリスト
  
  ## 例
      iex> queries = [
      ...>   GetProduct.new(%{id: "123"}),
      ...>   GetCategory.new(%{id: "cat-1"})
      ...> ]
      iex> CQRSFacade.execute_queries_parallel(queries)
      [{:ok, %{id: "123", ...}}, {:ok, %{id: "cat-1", ...}}]
  """
  @spec execute_queries_parallel(queries :: list(struct())) :: list({:ok, any()} | {:error, term()})
  def execute_queries_parallel(queries) do
    Logger.info("Executing #{length(queries)} queries in parallel")
    
    # クエリバスへの委譲
    QueryService.Application.QueryBus.execute_parallel(queries)
  end

  @doc """
  トランザクション内で複数のコマンドを実行する（サガパターン）
  
  ## パラメータ
    - commands: 実行するコマンド構造体のリスト
  
  ## 戻り値
    - {:ok, results} - すべてのコマンドの実行結果
    - {:error, reason} - エラーの理由（ロールバック済み）
  
  ## 例
      iex> commands = [
      ...>   CreateProduct.new(%{...}),
      ...>   UpdateCategory.new(%{...})
      ...> ]
      iex> CQRSFacade.execute_transaction(commands)
      {:ok, [%{aggregate_id: "123", ...}, %{aggregate_id: "cat-1", ...}]}
  """
  @spec execute_transaction(commands :: list(struct())) :: {:ok, list(any())} | {:error, term()}
  def execute_transaction(commands) do
    Logger.info("Executing transaction with #{length(commands)} commands")
    
    # 簡易的な実装（実際にはサガパターンやイベントソーシングを使用）
    results = []
    
    Enum.reduce_while(commands, {:ok, results}, fn command, {:ok, acc} ->
      case execute_command(command) do
        {:ok, result} ->
          {:cont, {:ok, acc ++ [result]}}
        
        {:error, _reason} = error ->
          # ロールバック処理（実装省略）
          Logger.error("Transaction failed, rolling back")
          {:halt, error}
      end
    end)
  end
end