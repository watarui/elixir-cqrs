defmodule Shared.Infrastructure.Saga.SagaTimeoutManager do
  @moduledoc """
  Sagaのタイムアウト管理を行うモジュール

  各ステップのタイムアウトを監視し、タイムアウト発生時に
  適切な補償処理を開始する。
  """

  use GenServer

  alias Shared.Infrastructure.Saga.{SagaState, SagaDefinition}

  require Logger

  @type timeout_info :: %{
          saga_id: String.t(),
          step_name: atom(),
          timeout_ms: non_neg_integer(),
          compensate_on_timeout: boolean()
        }

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  ステップのタイムアウトを開始
  """
  @spec start_timeout(String.t(), atom(), module(), SagaState.t()) ::
          {:ok, reference()} | {:error, term()}
  def start_timeout(saga_id, step_name, saga_module, saga_state, timeout_manager \\ __MODULE__) do
    timeout_ms = SagaDefinition.get_step_timeout(saga_module, step_name)

    if timeout_ms do
      compensate_on_timeout = SagaDefinition.compensate_on_timeout?(saga_module, step_name)

      timeout_info = %{
        saga_id: saga_id,
        step_name: step_name,
        timeout_ms: timeout_ms,
        compensate_on_timeout: compensate_on_timeout,
        saga_module: saga_module,
        saga_state: saga_state
      }

      GenServer.call(timeout_manager, {:start_timeout, timeout_info})
    else
      {:ok, nil}
    end
  end

  @doc """
  ステップのタイムアウトをキャンセル
  """
  @spec cancel_timeout(String.t(), atom()) :: :ok
  def cancel_timeout(saga_id, step_name, timeout_manager \\ __MODULE__) do
    GenServer.cast(timeout_manager, {:cancel_timeout, saga_id, step_name})
  end

  @doc """
  Saga全体のタイムアウトをキャンセル
  """
  @spec cancel_all_timeouts(String.t()) :: :ok
  def cancel_all_timeouts(saga_id, timeout_manager \\ __MODULE__) do
    GenServer.cast(timeout_manager, {:cancel_all_timeouts, saga_id})
  end

  @doc """
  アクティブなタイムアウトを取得
  """
  @spec get_active_timeouts() :: {:ok, list()}
  def get_active_timeouts(timeout_manager \\ __MODULE__) do
    GenServer.call(timeout_manager, :get_active_timeouts)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      # saga_id -> %{step_name -> {timer_ref, timeout_info}}
      active_timeouts: %{},
      # 統計情報
      stats: %{
        total_started: 0,
        total_cancelled: 0,
        total_triggered: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_timeout, timeout_info}, _from, state) do
    saga_id = timeout_info.saga_id
    step_name = timeout_info.step_name
    timeout_ms = timeout_info.timeout_ms

    # 既存のタイムアウトがあればキャンセル
    state = cancel_existing_timeout(state, saga_id, step_name)

    # 新しいタイムアウトを設定
    timer_ref = Process.send_after(self(), {:timeout_triggered, saga_id, step_name}, timeout_ms)

    Logger.info(
      "Started timeout for saga #{saga_id}, step #{step_name}, timeout: #{timeout_ms}ms"
    )

    # タイムアウト情報を保存
    saga_timeouts = Map.get(state.active_timeouts, saga_id, %{})
    updated_saga_timeouts = Map.put(saga_timeouts, step_name, {timer_ref, timeout_info})
    updated_active_timeouts = Map.put(state.active_timeouts, saga_id, updated_saga_timeouts)

    updated_stats = Map.update(state.stats, :total_started, 1, &(&1 + 1))

    new_state = %{state | active_timeouts: updated_active_timeouts, stats: updated_stats}

    # Telemetry イベントを発行
    :telemetry.execute(
      [:saga, :timeout, :started],
      %{timeout_ms: timeout_ms},
      %{saga_id: saga_id, step_name: step_name}
    )

    {:reply, {:ok, timer_ref}, new_state}
  end

  @impl true
  def handle_call(:get_active_timeouts, _from, state) do
    active_list =
      Enum.flat_map(state.active_timeouts, fn {saga_id, step_timeouts} ->
        Enum.map(step_timeouts, fn {step_name, {_timer_ref, timeout_info}} ->
          %{
            saga_id: saga_id,
            step_name: step_name,
            timeout_ms: timeout_info.timeout_ms,
            compensate_on_timeout: timeout_info.compensate_on_timeout
          }
        end)
      end)

    {:reply, {:ok, active_list}, state}
  end

  @impl true
  def handle_cast({:cancel_timeout, saga_id, step_name}, state) do
    new_state = cancel_existing_timeout(state, saga_id, step_name)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:cancel_all_timeouts, saga_id}, state) do
    case Map.get(state.active_timeouts, saga_id) do
      nil ->
        {:noreply, state}

      saga_timeouts ->
        # すべてのタイマーをキャンセル
        Enum.each(saga_timeouts, fn {step_name, {timer_ref, _}} ->
          Process.cancel_timer(timer_ref)
          Logger.info("Cancelled timeout for saga #{saga_id}, step #{step_name}")
        end)

        updated_active_timeouts = Map.delete(state.active_timeouts, saga_id)

        updated_stats =
          Map.update(
            state.stats,
            :total_cancelled,
            map_size(saga_timeouts),
            &(&1 + map_size(saga_timeouts))
          )

        new_state = %{state | active_timeouts: updated_active_timeouts, stats: updated_stats}

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:timeout_triggered, saga_id, step_name}, state) do
    Logger.warning("Timeout triggered for saga #{saga_id}, step #{step_name}")

    # タイムアウト情報を取得
    case get_in(state.active_timeouts, [saga_id, step_name]) do
      nil ->
        # すでにキャンセルされている
        {:noreply, state}

      {_timer_ref, timeout_info} ->
        # タイムアウト処理を実行
        handle_timeout(timeout_info)

        # タイムアウト情報を削除
        saga_timeouts = Map.get(state.active_timeouts, saga_id, %{})
        updated_saga_timeouts = Map.delete(saga_timeouts, step_name)

        updated_active_timeouts =
          if map_size(updated_saga_timeouts) == 0 do
            Map.delete(state.active_timeouts, saga_id)
          else
            Map.put(state.active_timeouts, saga_id, updated_saga_timeouts)
          end

        updated_stats = Map.update(state.stats, :total_triggered, 1, &(&1 + 1))

        new_state = %{state | active_timeouts: updated_active_timeouts, stats: updated_stats}

        # Telemetry イベントを発行
        :telemetry.execute(
          [:saga, :timeout, :triggered],
          %{},
          %{saga_id: saga_id, step_name: step_name}
        )

        {:noreply, new_state}
    end
  end

  # Private functions

  defp cancel_existing_timeout(state, saga_id, step_name) do
    case get_in(state.active_timeouts, [saga_id, step_name]) do
      nil ->
        state

      {timer_ref, _timeout_info} ->
        Process.cancel_timer(timer_ref)
        Logger.info("Cancelled existing timeout for saga #{saga_id}, step #{step_name}")

        saga_timeouts = Map.get(state.active_timeouts, saga_id, %{})
        updated_saga_timeouts = Map.delete(saga_timeouts, step_name)

        updated_active_timeouts =
          if map_size(updated_saga_timeouts) == 0 do
            Map.delete(state.active_timeouts, saga_id)
          else
            Map.put(state.active_timeouts, saga_id, updated_saga_timeouts)
          end

        updated_stats = Map.update(state.stats, :total_cancelled, 1, &(&1 + 1))

        %{state | active_timeouts: updated_active_timeouts, stats: updated_stats}
    end
  end

  defp handle_timeout(timeout_info) do
    saga_id = timeout_info.saga_id
    step_name = timeout_info.step_name
    compensate_on_timeout = timeout_info.compensate_on_timeout

    # SagaExecutorにタイムアウトを通知
    saga_executor = Process.whereis(Shared.Infrastructure.Saga.SagaExecutor)

    if saga_executor do
      send(saga_executor, {:step_timeout, saga_id, step_name, compensate_on_timeout})
    else
      Logger.error("SagaExecutor not found, cannot handle timeout for saga #{saga_id}")

      # デッドレターキューに送信
      Shared.Infrastructure.DeadLetterQueue.enqueue(
        "saga_timeout",
        %{
          saga_id: saga_id,
          step_name: step_name,
          timeout_info: timeout_info
        },
        :saga_executor_not_found,
        %{
          compensate_on_timeout: compensate_on_timeout
        }
      )
    end
  end
end
