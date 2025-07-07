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
            updated_at: DateTime.utc_now()
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
        {:error, _} ->
          :error
      end
    end)

    if Enum.any?(items_with_details, &(&1 == :error)) do
      {:error, "一部の商品情報を取得できませんでした"}
    else
      {:ok, items_with_details}
    end
  end

  defp get_product_info(product_id) do
    # CqrsFacadeを使用して商品情報を取得
    case CqrsFacade.query(CqrsFacade, {:get_product, product_id}) do
      {:ok, product} -> 
        {:ok, %{
          id: product.id,
          name: product.name,
          price: product.price
        }}
      {:error, _} = error -> error
    end
  end

  defp start_order_saga(saga_context) do
    # TODO: 実際にはgRPC経由でcommand-serviceに
    # サガ開始コマンドを送信する必要がある
    {:ok, "saga-#{saga_context.order_id}"}
  end

  defp validate_items(items) do
    # 在庫チェックなどのバリデーション
    # TODO: 実装
    :ok
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
      unit_price: item.unit_price,
      subtotal: item.subtotal
    }
  end
end