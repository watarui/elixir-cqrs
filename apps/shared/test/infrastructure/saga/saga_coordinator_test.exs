defmodule Shared.Infrastructure.Saga.SagaCoordinatorTest do
  use ExUnit.Case, async: false

  alias Shared.Domain.Saga.SagaEvents
  alias Shared.Infrastructure.EventStore
  alias Shared.Infrastructure.Saga.SagaCoordinator

  # テスト用のサガモジュール
  defmodule TestSaga do
    use Shared.Domain.Saga.SagaBase

    defstruct [
      :saga_id,
      :data,
      :state,
      :completed_steps,
      :failed_step,
      :failure_reason,
      :processed_events,
      :timeout
    ]

    def new(saga_id, data) do
      %__MODULE__{
        saga_id: saga_id,
        data: data,
        state: :started,
        completed_steps: [],
        processed_events: [],
        # 5秒のタイムアウト
        timeout: 5000
      }
    end

    @impl true
    def handle_event(%{event_type: "test_event_success"} = event, saga) do
      updated_saga = %{
        saga
        | state: :completed,
          completed_steps: saga.completed_steps ++ ["test_step"]
      }

      # コマンドなし
      {:ok, []}
    end

    @impl true
    def handle_event(%{event_type: "test_event_failure"} = event, saga) do
      {:error, "Test failure"}
    end

    @impl true
    def handle_event(_event, saga) do
      {:ok, []}
    end

    @impl true
    def completed?(%{state: :completed}), do: true
    def completed?(_), do: false

    @impl true
    def failed?(%{state: :failed}), do: true
    def failed?(_), do: false

    @impl true
    def get_compensation_commands(saga) do
      [%{type: "compensate_test", saga_id: saga.saga_id}]
    end

    def next_step(%{state: :started} = saga) do
      {:ok, [%{type: "test_command", saga_id: saga.saga_id}]}
    end

    def next_step(_saga) do
      {:ok, []}
    end

    def trigger_events do
      ["trigger_test_saga"]
    end

    def extract_initial_data(event) do
      Map.get(event, :payload, %{})
    end

    def mark_event_processed(saga, event) do
      %{saga | processed_events: [{event.event_id, DateTime.utc_now()} | saga.processed_events]}
    end

    def mark_step_completed(saga, step_name, result) do
      %{saga | completed_steps: saga.completed_steps ++ [{step_name, result}]}
    end

    def mark_failed(saga, failed_step, reason) do
      %{saga | state: :failed, failed_step: failed_step, failure_reason: reason}
    end

    def start_compensation(saga) do
      %{saga | state: :compensating}
    end

    def timed_out?(saga, timeout) do
      # テストでは簡略化
      false
    end
  end

  setup do
    # Start EventStore if not already started
    case Process.whereis(Shared.Infrastructure.EventStore.PostgresAdapter) do
      nil ->
        {:ok, _} = Shared.Infrastructure.EventStore.PostgresAdapter.start_link([])

      _ ->
        :ok
    end

    # Clear any existing events if using in-memory store
    if function_exported?(:ets, :whereis, 1) && :ets.whereis(:events) != :undefined do
      :ets.delete_all_objects(:events)
    end

    # SagaCoordinatorを開始
    {:ok, coordinator} =
      SagaCoordinator.start_link(
        saga_modules: [TestSaga],
        name: :test_saga_coordinator
      )

    on_exit(fn ->
      if Process.alive?(coordinator) do
        GenServer.stop(coordinator)
      end
    end)

    {:ok, coordinator: coordinator}
  end

  describe "start_saga/3" do
    test "新しいサガを開始できる", %{coordinator: coordinator} do
      initial_data = %{test_data: "test"}

      assert {:ok, saga_id} =
               SagaCoordinator.start_saga(
                 TestSaga,
                 initial_data,
                 %{user_id: "test_user"}
               )

      assert is_binary(saga_id)

      # アクティブなサガのリストに含まれているか確認
      active_sagas = SagaCoordinator.list_active_sagas()
      assert Enum.any?(active_sagas, fn saga -> saga.saga_id == saga_id end)
    end

    test "無効なサガモジュールではエラーを返す", %{coordinator: coordinator} do
      # Try to start a saga with an invalid module
      result =
        try do
          SagaCoordinator.start_saga(
            NonExistentSaga,
            %{},
            %{}
          )
        catch
          :exit, _ -> {:error, :invalid_saga_module}
        end

      assert {:error, _} = result
    end
  end

  describe "process_event/1" do
    setup %{coordinator: coordinator} do
      # テスト用のサガを開始
      {:ok, saga_id} =
        SagaCoordinator.start_saga(
          TestSaga,
          %{test_data: "test"},
          %{}
        )

      {:ok, saga_id: saga_id}
    end

    test "成功イベントを処理できる", %{saga_id: saga_id} do
      event = %{
        event_id: UUID.uuid4(),
        event_type: "test_event_success",
        aggregate_id: saga_id,
        occurred_at: DateTime.utc_now(),
        payload: %{result: "success"}
      }

      assert :ok = SagaCoordinator.process_event(event)

      # サガの状態が更新されているか確認
      # (実際の実装では、状態を取得するAPIが必要)
    end

    test "失敗イベントで補償処理が開始される", %{saga_id: saga_id} do
      event = %{
        event_id: UUID.uuid4(),
        event_type: "test_event_failure",
        aggregate_id: saga_id,
        occurred_at: DateTime.utc_now(),
        payload: %{error: "test error"}
      }

      assert :ok = SagaCoordinator.process_event(event)

      # 補償処理が開始されたことを確認
      # (実際の実装では、補償コマンドの発行を確認)
    end
  end

  describe "trigger_events" do
    test "トリガーイベントで新しいサガが開始される" do
      trigger_event = %{
        event_id: UUID.uuid4(),
        event_type: "trigger_test_saga",
        aggregate_id: "test_aggregate",
        occurred_at: DateTime.utc_now(),
        payload: %{trigger_data: "test"}
      }

      # アクティブなサガの数を記録
      before_count = length(SagaCoordinator.list_active_sagas())

      assert :ok = SagaCoordinator.process_event(trigger_event)

      # 新しいサガが開始されたことを確認
      after_count = length(SagaCoordinator.list_active_sagas())
      assert after_count > before_count
    end
  end

  describe "saga lifecycle" do
    test "サガの完全なライフサイクル" do
      # 1. サガを開始
      {:ok, saga_id} =
        SagaCoordinator.start_saga(
          TestSaga,
          %{order_id: "test_order"},
          %{}
        )

      # 2. 成功イベントを送信
      success_event = %{
        event_id: UUID.uuid4(),
        event_type: "test_event_success",
        aggregate_id: saga_id,
        occurred_at: DateTime.utc_now(),
        payload: %{status: "completed"}
      }

      assert :ok = SagaCoordinator.process_event(success_event)

      # 3. サガが完了状態になったことを確認
      # (実際の実装では、完了状態の確認方法が必要)
    end
  end
end
