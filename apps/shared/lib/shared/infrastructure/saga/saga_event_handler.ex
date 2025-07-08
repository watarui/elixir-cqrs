defmodule Shared.Infrastructure.Saga.SagaEventHandler do
  @moduledoc """
  ドメインイベントを監視してサガに転送するイベントハンドラー
  """

  use GenServer
  require Logger

  alias Shared.Infrastructure.EventBus
  alias Shared.Infrastructure.Saga.SagaCoordinator

  # イベントタイプとサガのマッピング
  # 注: 実際の運用では、アプリケーション設定から読み込むことを推奨
  @saga_triggers %{
                   # "order_created" => CommandService.Domain.Sagas.OrderSaga,
                   # 他のサガトリガーをここに追加
                 }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # EventBusにサブスクライブ
    EventBus.subscribe(self())

    # オプションからサガトリガーを取得（デフォルトは@saga_triggers）
    saga_triggers = Keyword.get(opts, :saga_triggers, @saga_triggers)

    state = %{
      processed_events: MapSet.new(),
      saga_triggers: saga_triggers,
      # メモリリークを防ぐため古いイベントIDを削除
      max_processed_events: 10_000
    }

    # 定期的なクリーンアップをスケジュール
    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_info({:event, event}, state) do
    event_id = get_event_id(event)

    # 重複処理を防ぐ
    if event_id && MapSet.member?(state.processed_events, event_id) do
      {:noreply, state}
    else
      new_state = process_event(event, state)
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:cleanup_processed_events, state) do
    # 処理済みイベントのリストが大きくなりすぎないようにクリーンアップ
    new_state =
      if MapSet.size(state.processed_events) > state.max_processed_events do
        %{state | processed_events: MapSet.new()}
      else
        state
      end

    # 次のクリーンアップをスケジュール
    schedule_cleanup()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp process_event(event, state) do
    # Get event type safely
    event_type = get_event_type(event)
    event_id = get_event_id(event)

    # イベントがサガのトリガーかチェック
    case Map.get(state.saga_triggers, event_type) do
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
    if event_id do
      %{state | processed_events: MapSet.put(state.processed_events, event_id)}
    else
      state
    end
  end

  defp saga_related_event?(event) do
    # イベントのmetadataにsaga_idが含まれているかチェック
    metadata = Map.get(event, :metadata, %{})
    Map.has_key?(metadata, :saga_id) or Map.has_key?(metadata, "saga_id")
  end

  defp start_new_saga(saga_module, event) do
    # イベントからサガの初期データを抽出
    initial_data = extract_saga_data(event)
    metadata = get_event_metadata(event)

    case SagaCoordinator.start_saga(saga_module, initial_data, metadata) do
      {:ok, saga_id} ->
        Logger.info("Started new saga",
          saga_type: saga_module,
          saga_id: saga_id,
          trigger_event: get_event_type(event)
        )

      {:error, reason} ->
        Logger.error("Failed to start saga",
          saga_type: saga_module,
          trigger_event: get_event_type(event),
          error: inspect(reason)
        )
    end
  end

  defp extract_saga_data(event) do
    case get_event_type(event) do
      "order_created" ->
        %{
          order_id: get_aggregate_id(event),
          customer_id:
            get_in(event, [:event_data, :customer_id]) || get_in(event, [:payload, :customer_id]),
          items: get_in(event, [:event_data, :items]) || get_in(event, [:payload, :items]),
          total_amount:
            get_in(event, [:event_data, :total_amount]) ||
              get_in(event, [:payload, :total_amount]),
          shipping_address:
            get_in(event, [:event_data, :shipping_address]) ||
              get_in(event, [:payload, :shipping_address])
        }

      _ ->
        # デフォルトはイベントデータ全体を使用
        Map.get(event, :event_data) || Map.get(event, :payload, %{})
    end
  end

  defp get_aggregate_id(event) when is_map(event) do
    Map.get(event, :aggregate_id) || Map.get(event, "aggregate_id")
  end

  defp get_aggregate_id(_), do: nil

  defp schedule_cleanup do
    # 1時間ごとにクリーンアップを実行
    Process.send_after(self(), :cleanup_processed_events, :timer.hours(1))
  end

  # Helper functions to safely get event properties
  defp get_event_type(event) when is_map(event) do
    Map.get(event, :event_type) || Map.get(event, "event_type")
  end

  defp get_event_type(event) when is_struct(event) do
    event.__struct__ |> Module.split() |> List.last()
  end

  defp get_event_type(_), do: nil

  defp get_event_id(event) when is_map(event) do
    Map.get(event, :event_id) || Map.get(event, "event_id")
  end

  defp get_event_id(_), do: nil

  defp get_event_metadata(event) when is_map(event) do
    Map.get(event, :event_metadata) || Map.get(event, :metadata, %{})
  end

  defp get_event_metadata(event) when is_struct(event) do
    Map.get(event, :metadata, %{})
  end

  defp get_event_metadata(_), do: %{}
end
