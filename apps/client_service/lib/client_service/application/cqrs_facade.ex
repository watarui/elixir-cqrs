defmodule ClientService.Application.CqrsFacade do
  @moduledoc """
  CQRSパターンのファサード
  
  コマンドとクエリの操作を統一的に扱い、
  内部的にgRPC接続を使用してcommand-serviceとquery-serviceと通信します。
  """

  use GenServer
  require Logger

  alias ClientService.Infrastructure.GrpcConnections
  alias Proto.{
    CategoryCommand,
    ProductCommand,
    CategoryUpParam,
    ProductUpParam
  }
  
  alias Query.{
    CategoryQuery,
    ProductQuery,
    CategoryQueryRequest,
    ListCategoriesQuery,
    ProductQueryRequest,
    ListProductsQuery,
    CategoryListResponse,
    ProductListResponse,
    Empty
  }

  # クライアントAPI

  @doc """
  CqrsFacadeプロセスを開始する
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  コマンドを実行する
  """
  @spec command(module(), tuple()) :: {:ok, map()} | {:error, term()}
  def command(server \\ __MODULE__, command) do
    GenServer.call(server, {:command, command})
  end

  @doc """
  クエリを実行する
  """
  @spec query(module(), tuple()) :: {:ok, map()} | {:error, term()}
  def query(server \\ __MODULE__, query) do
    GenServer.call(server, {:query, query})
  end

  # GenServerコールバック

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:command, command}, _from, state) do
    result = execute_command(command)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:query, query}, _from, state) do
    result = execute_query(query)
    {:reply, result, state}
  end

  # プライベート関数

  defp execute_command(command) do
    with {:ok, channel} <- GrpcConnections.get_command_channel() do
      case command do
        {:create_category, name} ->
          request = %CategoryUpParam{
            crud: :INSERT,
            name: name
          }
          call_command_service(channel, :category, request)

        {:update_category, id, name} ->
          request = %CategoryUpParam{
            crud: :UPDATE,
            id: id,
            name: name
          }
          call_command_service(channel, :category, request)

        {:delete_category, id} ->
          request = %CategoryUpParam{
            crud: :DELETE,
            id: id
          }
          call_command_service(channel, :category, request)

        {:create_product, params} ->
          request = %ProductUpParam{
            crud: :INSERT,
            name: params.name,
            price: params.price,
            categoryId: params[:category_id] || ""
          }
          call_command_service(channel, :product, request)

        {:update_product, id, params} ->
          request = %ProductUpParam{
            crud: :UPDATE,
            id: id,
            name: params[:name],
            price: params[:price],
            categoryId: params[:category_id]
          }
          call_command_service(channel, :product, request)

        {:delete_product, id} ->
          request = %ProductUpParam{
            crud: :DELETE,
            id: id
          }
          call_command_service(channel, :product, request)

        _ ->
          {:error, :unknown_command}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to get command channel: #{inspect(reason)}")
        {:error, :service_unavailable}
    end
  end

  defp execute_query(query) do
    with {:ok, channel} <- GrpcConnections.get_query_channel() do
      case query do
        {:get_category, id} ->
          request = %CategoryQueryRequest{id: id}
          call_query_service(channel, :get_category, request)

        {:list_categories} ->
          request = %Empty{}
          call_query_service(channel, :list_categories, request)

        {:get_product, id} ->
          request = %ProductQueryRequest{id: id}
          call_query_service(channel, :get_product, request)

        {:list_products} ->
          request = %Empty{}
          call_query_service(channel, :list_products, request)

        _ ->
          {:error, :unknown_query}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to get query channel: #{inspect(reason)}")
        {:error, :service_unavailable}
    end
  end

  defp call_command_service(channel, operation, request) do
    try do
      case operation do
        :category ->
          case CategoryCommand.Stub.update_category(channel, request) do
            {:ok, response} ->
              case response do
                %{category: nil, error: %{message: message}} ->
                  {:error, message}
                %{category: category} when not is_nil(category) ->
                  {:ok, %{id: category.id}}
                _ ->
                  {:error, "Unexpected response format"}
              end
            {:error, reason} ->
              Logger.error("gRPC call failed: #{inspect(reason)}")
              {:error, :grpc_error}
          end

        :product ->
          case ProductCommand.Stub.update_product(channel, request) do
            {:ok, response} ->
              case response do
                %{product: nil, error: %{message: message}} ->
                  {:error, message}
                %{product: product} when not is_nil(product) ->
                  {:ok, %{id: product.id}}
                _ ->
                  {:error, "Unexpected response format"}
              end
            {:error, reason} ->
              Logger.error("gRPC call failed: #{inspect(reason)}")
              {:error, :grpc_error}
          end
      end
    catch
      error ->
        Logger.error("Exception in command service call: #{inspect(error)}")
        {:error, :internal_error}
    end
  end

  defp call_query_service(channel, operation, request) do
    try do
      case operation do
        :get_category ->
          case CategoryQuery.Stub.get_category(channel, request) do
            {:ok, response} ->
              {:ok, category_to_map(response.category)}
            {:error, %GRPC.RPCError{status: 5}} ->
              {:error, :not_found}
            {:error, reason} ->
              Logger.error("gRPC call failed: #{inspect(reason)}")
              {:error, :grpc_error}
          end

        :list_categories ->
          case CategoryQuery.Stub.list_categories(channel, request) do
            {:ok, response} ->
              {:ok, Enum.map(response.categories, &category_to_map/1)}
            {:error, reason} ->
              Logger.error("gRPC call failed: #{inspect(reason)}")
              {:error, :grpc_error}
          end

        :get_product ->
          case ProductQuery.Stub.get_product(channel, request) do
            {:ok, response} ->
              {:ok, product_to_map(response.product)}
            {:error, %GRPC.RPCError{status: 5}} ->
              {:error, :not_found}
            {:error, reason} ->
              Logger.error("gRPC call failed: #{inspect(reason)}")
              {:error, :grpc_error}
          end

        :list_products ->
          case ProductQuery.Stub.list_products(channel, request) do
            {:ok, response} ->
              {:ok, Enum.map(response.products, &product_to_map/1)}
            {:error, reason} ->
              Logger.error("gRPC call failed: #{inspect(reason)}")
              {:error, :grpc_error}
          end
      end
    catch
      error ->
        Logger.error("Exception in query service call: #{inspect(error)}")
        {:error, :internal_error}
    end
  end

  defp category_to_map(nil), do: nil
  
  defp category_to_map(category) do
    %{
      id: category.id,
      name: category.name,
      created_at: category.created_at,
      updated_at: category.updated_at
    }
  end

  defp product_to_map(nil), do: nil
  
  defp product_to_map(product) do
    %{
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      stock_quantity: product.stock_quantity,
      category_id: product.category_id,
      created_at: product.created_at,
      updated_at: product.updated_at
    }
  end
end