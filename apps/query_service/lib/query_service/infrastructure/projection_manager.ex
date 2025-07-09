defmodule QueryService.Infrastructure.ProjectionManager do
  @moduledoc """
  プロジェクションマネージャー

  EventBus からイベントをリアルタイムで受信し、Read Model を更新します
  """

  use GenServer

  alias Shared.Infrastructure.EventBus
  alias Shared.Infrastructure.EventStore.EventStore

  alias QueryService.Infrastructure.Projections.{
    CategoryProjection,
    ProductProjection,
    OrderProjection
  }

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # 初期状態
    state = %{
      projections: [
        CategoryProjection,
        ProductProjection,
        OrderProjection
      ]
    }

    # すべてのイベントを購読
    EventBus.subscribe_all()
    Logger.info("ProjectionManager started and subscribed to all events")

    # 起動時に既存のイベントを処理（オプション）
    Process.send_after(self(), :process_existing_events, 1_000)

    {:ok, state}
  end

  @impl true
  def handle_info({:event, event_type, event}, state) do
    # EventBus からイベントを受信
    Logger.debug("Received event: #{event_type}")

    # 各プロジェクションでイベントを処理
    Enum.each(state.projections, fn projection ->
      try do
        projection.handle_event(event)
      rescue
        e ->
          Logger.error("Projection error in #{projection}: #{inspect(e)}")
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:process_existing_events, state) do
    # 起動時に既存のイベントを処理（キャッチアップ）
    case EventStore.get_events(limit: 10_000) do
      {:ok, events} when events != [] ->
        Logger.info("Processing #{length(events)} existing events for catch-up")
        process_events(events, state.projections)

      {:ok, []} ->
        Logger.info("No existing events to process")

      {:error, reason} ->
        Logger.error("Failed to fetch existing events: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  defp process_events(events, projections) do
    Enum.each(events, fn event ->
      # 各プロジェクションでイベントを処理
      Enum.each(projections, fn projection ->
        try do
          projection.handle_event(event)
        rescue
          e ->
            Logger.error("Projection error in #{projection}: #{inspect(e)}")
        end
      end)
    end)
  end
end
