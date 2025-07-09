defmodule QueryService.Infrastructure.ProjectionManager do
  @moduledoc """
  プロジェクションマネージャー

  イベントストアからイベントを読み取り、Read Model を更新します
  """

  use GenServer

  alias Shared.Infrastructure.EventStore.EventStore

  alias QueryService.Infrastructure.Projections.{
    CategoryProjection,
    ProductProjection,
    OrderProjection
  }

  require Logger

  # 1秒ごとにポーリング
  @poll_interval 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # 初期状態
    state = %{
      last_processed_id: 0,
      projections: [
        CategoryProjection,
        ProductProjection,
        OrderProjection
      ]
    }

    # ポーリングを開始
    Process.send_after(self(), :poll_events, @poll_interval)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll_events, state) do
    # 新しいイベントを取得
    case EventStore.get_events_after(state.last_processed_id) do
      {:ok, events} when events != [] ->
        Logger.info("Processing #{length(events)} new events")

        # 各イベントを処理
        last_id = process_events(events, state.projections)

        # 次回のポーリングをスケジュール
        Process.send_after(self(), :poll_events, @poll_interval)

        {:noreply, %{state | last_processed_id: last_id}}

      {:ok, []} ->
        # 新しいイベントがない場合
        Process.send_after(self(), :poll_events, @poll_interval)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to fetch events: #{inspect(reason)}")
        Process.send_after(self(), :poll_events, @poll_interval)
        {:noreply, state}
    end
  end

  defp process_events(events, projections) do
    Enum.reduce(events, 0, fn event, _acc ->
      # 各プロジェクションでイベントを処理
      Enum.each(projections, fn projection ->
        try do
          projection.handle_event(event)
        rescue
          e ->
            Logger.error("Projection error in #{projection}: #{inspect(e)}")
        end
      end)

      # 最後に処理したイベントIDを返す
      event.id
    end)
  end
end
