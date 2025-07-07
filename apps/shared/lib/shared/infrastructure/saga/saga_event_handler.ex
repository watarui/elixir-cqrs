defmodule Shared.Infrastructure.Saga.SagaEventHandler do
  @moduledoc """
  ドメインイベントを監視してサガに転送するイベントハンドラー
  """
  
  use GenServer
  require Logger
  
  alias Shared.Infrastructure.EventBus
  alias Shared.Infrastructure.Saga.SagaCoordinator
  
  # イベントタイプとサガのマッピング
  @saga_triggers %{
    "order_created" => CommandService.Domain.Sagas.OrderSaga,
    # 他のサガトリガーをここに追加
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    # EventBusにサブスクライブ
    EventBus.subscribe(self())
    
    state = %{
      processed_events: MapSet.new(),
      saga_triggers: @saga_triggers
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_info({:event, event}, state) do
    # 重複処理を防ぐ
    if MapSet.member?(state.processed_events, event.event_id) do
      {:noreply, state}
    else
      new_state = process_event(event, state)
      {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  # Private functions
  
  defp process_event(event, state) do
    # イベントがサガのトリガーかチェック
    case Map.get(state.saga_triggers, event.event_type) do
      nil ->
        # 既存のサガに関連するイベントの可能性
        if saga_related_event?(event) do
          SagaCoordinator.process_event(event)
        end
        
      saga_module ->
        # 新しいサガを開始
        start_new_saga(saga_module, event)
    end
    
    # 処理済みとして記録
    %{state | processed_events: MapSet.put(state.processed_events, event.event_id)}
  end
  
  defp saga_related_event?(event) do
    # イベントのmetadataにsaga_idが含まれているかチェック
    Map.has_key?(event[:metadata] || %{}, :saga_id)
  end
  
  defp start_new_saga(saga_module, event) do
    # イベントからサガの初期データを抽出
    initial_data = extract_saga_data(event)
    
    case SagaCoordinator.start_saga(saga_module, initial_data, event.metadata) do
      {:ok, saga_id} ->
        Logger.info("Started new saga",
          saga_type: saga_module,
          saga_id: saga_id,
          trigger_event: event.event_type
        )
        
      {:error, reason} ->
        Logger.error("Failed to start saga",
          saga_type: saga_module,
          trigger_event: event.event_type,
          error: inspect(reason)
        )
    end
  end
  
  defp extract_saga_data(event) do
    case event.event_type do
      "order_created" ->
        %{
          order_id: event.aggregate_id,
          customer_id: get_in(event, [:payload, :customer_id]),
          items: get_in(event, [:payload, :items]),
          total_amount: get_in(event, [:payload, :total_amount]),
          shipping_address: get_in(event, [:payload, :shipping_address])
        }
        
      _ ->
        # デフォルトはペイロード全体を使用
        event.payload
    end
  end
end