defmodule QueryService.Application.QueryBus do
  @moduledoc """
  クエリバス（メディエーターパターンの実装）
  
  クエリを適切なハンドラーにルーティングし、実行結果を返します
  """

  use GenServer
  require Logger

  alias QueryService.Application.Handlers.{
    ProductQueryHandler,
    CategoryQueryHandler
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  クエリを実行する
  """
  @spec execute(query :: struct()) :: {:ok, any()} | {:error, term()}
  def execute(query) do
    GenServer.call(get_server(), {:execute, query})
  end

  @doc """
  複数のクエリを並列実行する
  """
  @spec execute_parallel(queries :: list(struct())) :: list({:ok, any()} | {:error, term()})
  def execute_parallel(queries) do
    queries
    |> Enum.map(fn query ->
      Task.async(fn -> execute(query) end)
    end)
    |> Enum.map(&Task.await/1)
  end

  # Server callbacks

  @impl GenServer
  def init(:ok) do
    # ハンドラーレジストリを初期化
    registry = build_handler_registry()
    {:ok, %{registry: registry}}
  end

  @impl GenServer
  def handle_call({:execute, query}, _from, state) do
    result = execute_query(query, state.registry)
    {:reply, result, state}
  end

  # Private functions

  defp get_server do
    case Process.whereis(__MODULE__) do
      nil -> 
        {:ok, pid} = start_link(name: __MODULE__)
        pid
      pid -> 
        pid
    end
  end

  defp build_handler_registry do
    handlers = [
      ProductQueryHandler,
      CategoryQueryHandler
    ]

    Enum.reduce(handlers, %{}, fn handler, acc ->
      Enum.reduce(handler.query_types(), acc, fn query_type, inner_acc ->
        Map.put(inner_acc, query_type, handler)
      end)
    end)
  end

  defp execute_query(query, registry) do
    query_type = query.__struct__
    
    case Map.get(registry, query_type) do
      nil ->
        {:error, "No handler found for query: #{inspect(query_type)}"}
      
      handler ->
        Logger.info("Executing query #{inspect(query_type)} with handler #{inspect(handler)}")
        
        try do
          handler.handle_query(query)
        rescue
          e ->
            Logger.error("Error executing query: #{inspect(e)}")
            {:error, Exception.message(e)}
        end
    end
  end
end