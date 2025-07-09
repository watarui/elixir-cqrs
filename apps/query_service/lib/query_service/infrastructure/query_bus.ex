defmodule QueryService.Infrastructure.QueryBus do
  @moduledoc """
  クエリバス

  クエリを適切なハンドラーにルーティングし、実行します。
  """

  use GenServer
  require Logger

  @type query :: struct()
  @type handler :: module()
  @type result :: {:ok, any()} | {:error, any()}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  クエリを実行する
  """
  @spec execute(query()) :: result()
  def execute(query) do
    GenServer.call(__MODULE__, {:execute, query})
  end

  @doc """
  ハンドラーを登録する
  """
  @spec register_handler(String.t(), handler()) :: :ok
  def register_handler(query_type, handler) do
    GenServer.call(__MODULE__, {:register_handler, query_type, handler})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      handlers: %{
        # クエリタイプとハンドラーのマッピング
        "category.get_by_id" => QueryService.Application.Handlers.CategoryQueryHandler,
        "category.get_all" => QueryService.Application.Handlers.CategoryQueryHandler,
        "category.search" => QueryService.Application.Handlers.CategoryQueryHandler,
        "product.get_by_id" => QueryService.Application.Handlers.ProductQueryHandler,
        "product.get_all" => QueryService.Application.Handlers.ProductQueryHandler,
        "product.get_by_category" => QueryService.Application.Handlers.ProductQueryHandler,
        "product.search" => QueryService.Application.Handlers.ProductQueryHandler,
        "order.get_by_id" => QueryService.Application.Handlers.OrderQueryHandler,
        "order.get_by_user" => QueryService.Application.Handlers.OrderQueryHandler,
        "order.search" => QueryService.Application.Handlers.OrderQueryHandler
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:execute, query}, _from, state) do
    result = execute_query(query, state.handlers)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:register_handler, query_type, handler}, _from, state) do
    new_handlers = Map.put(state.handlers, query_type, handler)
    {:reply, :ok, %{state | handlers: new_handlers}}
  end

  # Private functions

  defp execute_query(query, handlers) do
    query_type = get_query_type(query)

    case Map.get(handlers, query_type) do
      nil ->
        Logger.error("No handler registered for query type: #{query_type}")
        {:error, :handler_not_found}

      handler ->
        try do
          Logger.info("Executing query: #{query_type}")
          handler.handle(query)
        rescue
          error ->
            Logger.error("Error executing query: #{inspect(error)}")
            {:error, :execution_failed}
        end
    end
  end

  defp get_query_type(query) do
    cond do
      function_exported?(query.__struct__, :query_type, 0) ->
        query.__struct__.query_type()

      Map.has_key?(query, :query_type) ->
        query.query_type

      true ->
        # モジュール名から推測
        query.__struct__
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
    end
  end
end
