defmodule ClientService.GraphQL.Resolvers.OrderResolver do
  @moduledoc """
  注文関連のGraphQLリゾルバー
  サガパターンを使用した分散トランザクション処理
  """

  alias ClientService.Application.CqrsFacade
  require Logger

  @doc """
  注文を作成する（サガパターンを使用）
  """
  @spec create_order(map(), map(), map()) :: {:ok, map()} | {:error, String.t()}
  def create_order(_parent, %{input: input}, _context) do
    order_id = generate_order_id()
    
    # 商品情報を取得して注文アイテムを作成
    with {:ok, items_with_details} <- fetch_product_details(input.items),
         :ok <- validate_items(items_with_details),
         total_amount <- calculate_total(items_with_details) do
      
      # OrderSagaを開始
      saga_context = %{
        order_id: order_id,
        customer_id: input.user_id,  # OrderSagaではcustomer_idという名前を使用
        items: items_with_details,
        total_amount: total_amount,
        shipping_address: %{
          # TODO: 実際の配送先情報を受け取る
          street: "123 Main St",
          city: "Tokyo",
          postal_code: "100-0001"
        }
      }

      # TODO: SagaCoordinatorはcommand-service内部のモジュールなので、
      # gRPC経由でサガを開始するコマンドを送信する必要がある
      case start_order_saga(saga_context) do
        {:ok, _saga_id} ->
          # 注文の初期状態を返す
          order = %{
            id: order_id,
            user_id: input.user_id,
            status: :processing,
            total_amount: total_amount,
            items: Enum.map(items_with_details, &format_order_item/1),
            created_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now(),
            saga_state: %{
              state: "started",
              status: :started,
              started_at: DateTime.utc_now(),
              completed_at: nil,
              current_step: "order_initiated",
              failure_reason: nil
            }
          }
          
          {:ok, order}
          
        {:error, reason} ->
          Logger.error("Failed to start order saga: #{inspect(reason)}")
          {:error, "注文の処理を開始できませんでした"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  注文をキャンセルする
  """
  @spec cancel_order(map(), map(), map()) :: {:ok, boolean()} | {:error, String.t()}
  def cancel_order(_parent, %{input: _input}, _context) do
    # TODO: 実装
    # 1. 注文の現在の状態を確認
    # 2. キャンセル可能な状態かチェック
    # 3. サガの補償処理を開始
    {:ok, true}
  end

  @doc """
  注文を取得する
  """
  @spec get_order(map(), map(), map()) :: {:ok, map()} | {:error, String.t()}
  def get_order(_parent, %{id: order_id}, _context) do
    # TODO: クエリサービスから注文情報を取得
    # 現在は仮の実装
    {:ok, %{
      id: order_id,
      user_id: "user-123",
      status: :confirmed,
      total_amount: 1500.0,
      items: [],
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }}
  end

  @doc """
  ユーザーの注文一覧を取得する
  """
  @spec list_user_orders(map(), map(), map()) :: {:ok, list(map())} | {:error, String.t()}
  def list_user_orders(_parent, %{user_id: _user_id}, _context) do
    # TODO: クエリサービスから注文一覧を取得
    {:ok, []}
  end

  @doc """
  サガの状態を取得する
  """
  @spec get_saga_state(map(), map(), map()) :: {:ok, map()} | {:error, String.t()}
  def get_saga_state(_parent, %{order_id: order_id}, _context) do
    # TODO: サガの状態を取得
    {:ok, %{
      saga_id: "saga-#{order_id}",
      state: :completed,
      completed_steps: ["reserve_inventory", "process_payment", "arrange_shipping", "confirm_order"],
      error: nil,
      started_at: DateTime.utc_now(),
      completed_at: DateTime.utc_now()
    }}
  end
  
  @doc """
  Order SAGAを開始する
  """
  def start_order_saga(_parent, %{input: input}, _resolution) do
    saga_context = %{
      order_id: input.order_id,
      user_id: input.user_id,
      items: Enum.map(input.items, fn item ->
        %{
          product_id: item.product_id,
          quantity: item.quantity
        }
      end),
      total_amount: input.total_amount
    }
    
    case CqrsFacade.start_order_saga(saga_context) do
      {:ok, saga_id} ->
        {:ok, %{
          saga_id: saga_id,
          success: true,
          message: "Order SAGA started successfully",
          started_at: DateTime.utc_now()
        }}
      {:error, reason} ->
        {:ok, %{
          saga_id: "",
          success: false,
          message: "Failed to start SAGA: #{inspect(reason)}",
          started_at: DateTime.utc_now()
        }}
    end
  end

  # Private functions

  defp generate_order_id do
    "order-#{System.unique_integer([:positive, :monotonic])}-#{:rand.uniform(999999)}"
  end

  defp fetch_product_details(items) do
    # 各商品の詳細情報を取得
    items_with_details = Enum.map(items, fn item ->
      case get_product_info(item.product_id) do
        {:ok, product} ->
          %{
            product_id: item.product_id,
            product_name: product.name,
            quantity: item.quantity,
            unit_price: product.price,
            subtotal: product.price * item.quantity
          }
        {:error, reason} ->
          Logger.warn("Product not found, using fallback: #{inspect(reason)}")
          # フォールバック: 商品情報が取得できない場合でも処理を続行
          %{
            product_id: item.product_id,
            product_name: "Product #{item.product_id}",
            quantity: item.quantity,
            unit_price: 0.0,
            subtotal: 0.0
          }
      end
    end)

    {:ok, items_with_details}
  end

  defp get_product_info(product_id) do
    # CqrsFacadeを使用して商品情報を取得
    Logger.info("Fetching product info for: #{product_id}")
    
    result = CqrsFacade.query({:get_product, product_id})
    Logger.info("Product query result: #{inspect(result)}")
    
    case result do
      {:ok, product} -> 
        {:ok, %{
          id: product.id,
          name: product.name,
          price: product.price
        }}
      {:error, reason} = error -> 
        Logger.error("Failed to fetch product: #{inspect(reason)}")
        error
    end
  end

  defp start_order_saga(saga_context) do
    # gRPC経由でcommand-serviceにサガ開始コマンドを送信
    case CqrsFacade.start_order_saga(saga_context) do
      {:ok, saga_id} -> {:ok, saga_id}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_items(items) do
    # 商品の基本検証
    cond do
      Enum.empty?(items) ->
        {:error, "Order must have at least one item"}
        
      Enum.any?(items, &(&1.quantity <= 0)) ->
        {:error, "Item quantity must be positive"}
        
      Enum.any?(items, &(&1.unit_price < 0)) ->
        {:error, "Item price cannot be negative"}
        
      true ->
        # 在庫チェックはサガのreserve_inventoryステップで実行される
        :ok
    end
  end

  defp calculate_total(items) do
    Enum.reduce(items, 0.0, fn item, acc ->
      acc + item.subtotal
    end)
  end

  defp format_order_item(item) do
    %{
      product_id: item.product_id,
      product_name: item.product_name,
      quantity: item.quantity,
      price: item.unit_price,
      subtotal: item.subtotal
    }
  end
  
  defp format_order_items(nil), do: []
  defp format_order_items(items) when is_list(items) do
    Enum.map(items, &format_order_item/1)
  end
  
  defp validate_cancellable_status(status) do
    cancellable_statuses = [:pending, :processing, :confirmed]
    
    if status in cancellable_statuses do
      :ok
    else
      {:error, :not_cancellable}
    end
  end
  
  defp get_saga_state_internal(order_id) do
    # サガの状態を取得
    saga_id = "saga-#{order_id}"
    
    case CqrsFacade.query({:get_saga_status, saga_id}) do
      {:ok, saga} ->
        {:ok, %{
          saga_id: saga.saga_id,
          state: saga.state,
          completed_steps: saga.completed_steps || [],
          current_step: saga.current_step,
          error: saga.error,
          started_at: saga.started_at,
          completed_at: saga.completed_at
        }}
        
      {:error, :not_found} ->
        # サガが見つからない場合はnilを返す
        {:ok, nil}
        
      {:error, reason} ->
        Logger.error("Failed to fetch saga state: #{inspect(reason)}")
        {:error, reason}
    end
  end
end