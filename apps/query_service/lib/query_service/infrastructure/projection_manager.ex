defmodule QueryService.Infrastructure.ProjectionManager do
  @moduledoc """
  プロジェクションマネージャー

  - リアルタイムイベント処理（EventBus 購読）
  - プロジェクション再構築機能
  - エラーハンドリングとリトライ
  - 並列処理対応
  """

  use GenServer

  alias Shared.Infrastructure.EventStore.EventStore
  alias Shared.Infrastructure.EventBus

  alias QueryService.Infrastructure.Projections.{
    CategoryProjection,
    ProductProjection,
    OrderProjection
  }

  require Logger

  # リトライ設定
  @max_retries 3
  @retry_delay 1_000

  # バッチ処理設定
  @batch_size 100

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  特定のプロジェクションを再構築する
  """
  def rebuild_projection(projection_module) do
    GenServer.call(__MODULE__, {:rebuild_projection, projection_module}, :infinity)
  end

  @doc """
  すべてのプロジェクションを再構築する
  """
  def rebuild_all_projections do
    GenServer.call(__MODULE__, :rebuild_all_projections, :infinity)
  end

  @doc """
  プロジェクションの状態を取得する
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %{
      projections: %{
        CategoryProjection => %{status: :running, last_error: nil, processed_count: 0},
        ProductProjection => %{status: :running, last_error: nil, processed_count: 0},
        OrderProjection => %{status: :running, last_error: nil, processed_count: 0}
      },
      subscriptions: %{},
      rebuilding: false
    }

    # EventBus に購読
    {:ok, subscribe_to_events(state)}
  end

  @impl true
  def handle_call({:rebuild_projection, projection_module}, _from, state) do
    Logger.info("Starting rebuild for projection: #{projection_module}")

    result = do_rebuild_projection(projection_module)

    {:reply, result, state}
  end

  @impl true
  def handle_call(:rebuild_all_projections, _from, state) do
    Logger.info("Starting rebuild for all projections")

    # 一時的に購読を解除
    state = unsubscribe_all(state)

    results =
      Enum.map(Map.keys(state.projections), fn projection_module ->
        {projection_module, do_rebuild_projection(projection_module)}
      end)

    # 購読を再開
    state = subscribe_to_events(state)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.projections, state}
  end

  @impl true
  def handle_info({:event, event_type, event}, state) do
    # リアルタイムイベント処理
    state = process_realtime_event(event_type, event, state)
    {:noreply, state}
  end

  # Private functions

  defp subscribe_to_events(state) do
    # 各イベントタイプに購読
    event_types = [
      :category_created,
      :category_updated,
      :category_deleted,
      :product_created,
      :product_updated,
      :product_price_changed,
      :product_deleted,
      :order_placed,
      :order_payment_completed,
      :order_shipped,
      :order_delivered,
      :order_cancelled
    ]

    subscriptions =
      Enum.reduce(event_types, %{}, fn event_type, acc ->
        :ok = EventBus.subscribe(event_type)
        Map.put(acc, event_type, event_type)
      end)

    %{state | subscriptions: subscriptions}
  end

  defp unsubscribe_all(state) do
    Enum.each(state.subscriptions, fn {_event_type, subscription} ->
      EventBus.unsubscribe(subscription)
    end)

    %{state | subscriptions: %{}}
  end

  defp process_realtime_event(event_type, event, state) do
    # 該当するプロジェクションを特定
    projections_to_update = get_projections_for_event(event_type)

    # 各プロジェクションでイベントを処理
    updated_projections =
      Enum.reduce(projections_to_update, state.projections, fn projection_module, acc ->
        case process_event_with_retry(projection_module, event) do
          :ok ->
            update_projection_status(acc, projection_module, :processed)

          {:error, reason} ->
            Logger.error("Failed to process event in #{projection_module}: #{inspect(reason)}")
            update_projection_status(acc, projection_module, :error, reason)
        end
      end)

    %{state | projections: updated_projections}
  end

  defp get_projections_for_event(event_type) do
    # イベントタイプに基づいて更新すべきプロジェクションを決定
    case event_type do
      event when event in [:category_created, :category_updated, :category_deleted] ->
        [CategoryProjection]

      event
      when event in [:product_created, :product_updated, :product_price_changed, :product_deleted] ->
        [ProductProjection]

      event
      when event in [
             :order_placed,
             :order_payment_completed,
             :order_shipped,
             :order_delivered,
             :order_cancelled
           ] ->
        [OrderProjection]

      _ ->
        []
    end
  end

  defp process_event_with_retry(projection_module, event, retry_count \\ 0) do
    try do
      projection_module.handle_event(event)
      :ok
    rescue
      e ->
        if retry_count < @max_retries do
          Process.sleep(@retry_delay)
          process_event_with_retry(projection_module, event, retry_count + 1)
        else
          {:error, e}
        end
    end
  end

  defp do_rebuild_projection(projection_module) do
    Logger.info("Rebuilding projection: #{projection_module}")

    # プロジェクションをクリア
    case projection_module.clear_all() do
      :ok ->
        # すべてのイベントを再処理
        rebuild_from_event_store(projection_module)

      {:error, reason} ->
        {:error, {:clear_failed, reason}}
    end
  end

  defp rebuild_from_event_store(projection_module) do
    # バッチでイベントを処理
    process_events_in_batches(projection_module, 0, 0)
  end

  defp process_events_in_batches(projection_module, after_id, processed_count) do
    case EventStore.get_events_after(after_id, @batch_size) do
      {:ok, []} ->
        Logger.info(
          "Rebuild completed for #{projection_module}. Processed #{processed_count} events."
        )

        {:ok, processed_count}

      {:ok, events} ->
        # バッチ内のイベントを処理
        Enum.each(events, fn event ->
          # 該当するイベントのみ処理
          if should_process_event?(projection_module, event) do
            process_event_with_retry(projection_module, event)
          end
        end)

        last_id = List.last(events).id
        new_count = processed_count + length(events)

        # 次のバッチを処理
        process_events_in_batches(projection_module, last_id, new_count)

      {:error, reason} ->
        Logger.error("Failed to fetch events: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp should_process_event?(projection_module, event) do
    event_type = String.to_atom(event.__struct__.event_type())
    event_type in get_handled_events(projection_module)
  end

  defp get_handled_events(CategoryProjection) do
    [:category_created, :category_updated, :category_deleted]
  end

  defp get_handled_events(ProductProjection) do
    [:product_created, :product_updated, :product_price_changed, :product_deleted]
  end

  defp get_handled_events(OrderProjection) do
    [:order_placed, :order_payment_completed, :order_shipped, :order_delivered, :order_cancelled]
  end

  defp update_projection_status(projections, projection_module, :processed) do
    Map.update!(projections, projection_module, fn status ->
      %{status | status: :running, last_error: nil, processed_count: status.processed_count + 1}
    end)
  end

  defp update_projection_status(projections, projection_module, :error, reason) do
    Map.update!(projections, projection_module, fn status ->
      %{status | status: :error, last_error: inspect(reason)}
    end)
  end
end
