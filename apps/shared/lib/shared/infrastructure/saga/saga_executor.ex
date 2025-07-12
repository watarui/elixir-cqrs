defmodule Shared.Infrastructure.Saga.SagaExecutor do
  @moduledoc """
  Sagaの実行を管理するGenServer

  Sagaの開始、ステップの実行、補償処理、タイムアウト処理などを
  一元的に管理する。
  """

  use GenServer

  alias Shared.Infrastructure.Saga.{
    SagaDefinition,
    SagaLockManager,
    SagaState,
    SagaTimeoutManager
  }

  alias Shared.Infrastructure.DeadLetterQueue
  alias Shared.Infrastructure.EventBus
  alias Shared.Infrastructure.Idempotency.IdempotentSaga
  alias Shared.Infrastructure.Retry.RetryStrategy
  alias Shared.Infrastructure.Saga.SagaRepository

  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  新しいSagaを開始
  """
  @spec start_saga(module(), struct(), map()) :: {:ok, String.t()} | {:error, term()}
  def start_saga(saga_module, trigger_event, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:start_saga, saga_module, trigger_event, metadata})
  end

  @doc """
  イベントを処理
  """
  @spec handle_event(struct()) :: :ok
  def handle_event(event) do
    GenServer.cast(__MODULE__, {:handle_event, event})
  end

  @doc """
  アクティブなSagaを取得
  """
  @spec get_active_sagas() :: {:ok, map()}
  def get_active_sagas do
    GenServer.call(__MODULE__, :get_active_sagas)
  end

  @doc """
  Sagaの状態を取得
  """
  @spec get_saga_state(String.t()) :: {:ok, SagaState.t()} | {:error, :not_found}
  def get_saga_state(saga_id) do
    GenServer.call(__MODULE__, {:get_saga_state, saga_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # イベントバスに登録
    EventBus.subscribe_all()

    # アクティブなSagaを復元
    active_sagas = restore_active_sagas()

    state = %{
      active_sagas: active_sagas,
      stats: %{
        total_started: 0,
        total_completed: 0,
        total_failed: 0,
        total_compensated: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_saga, saga_module, trigger_event, metadata}, _from, state) do
    saga_id = UUID.uuid4()

    # Sagaレベルのロックを取得（重複実行防止）
    case SagaLockManager.acquire_saga_lock(saga_id, timeout: 5_000) do
      {:ok, lock_ref} ->
        try do
          # 初期状態を作成
          initial_data = saga_module.initial_state(trigger_event)

          saga_state =
            SagaState.new(saga_id, saga_module, initial_data, metadata)
            |> Map.put(:lock_ref, lock_ref)

          # 永続化
          case SagaRepository.save(saga_state) do
            {:ok, _saga_id} ->
              # 最初のステップを実行
              updated_saga_state = execute_next_step(saga_state)

              # アクティブなSagaに追加
              updated_active_sagas = Map.put(state.active_sagas, saga_id, updated_saga_state)
              updated_stats = Map.update(state.stats, :total_started, 1, &(&1 + 1))

              new_state = %{state | active_sagas: updated_active_sagas, stats: updated_stats}

              Logger.info("Started saga #{saga_module} with id #{saga_id}")

              # Telemetry イベント
              :telemetry.execute(
                [:saga, :started],
                %{},
                %{saga_id: saga_id, saga_type: saga_module}
              )

              {:reply, {:ok, saga_id}, new_state}

            {:error, reason} ->
              # ロックを解放
              SagaLockManager.release_lock(lock_ref)
              Logger.error("Failed to save saga: #{inspect(reason)}")
              {:reply, {:error, reason}, state}
          end
        rescue
          e ->
            # ロックを解放
            SagaLockManager.release_lock(lock_ref)
            Logger.error("Failed to start saga: #{inspect(e)}")
            {:reply, {:error, e}, state}
        end

      {:error, :locked} ->
        Logger.warning("Saga #{saga_id} is already being processed")
        {:reply, {:error, :duplicate_execution}, state}

      {:error, reason} ->
        Logger.error("Failed to acquire lock for saga #{saga_id}: #{inspect(reason)}")
        {:reply, {:error, {:lock_failed, reason}}, state}
    end
  end

  @impl true
  def handle_call(:get_active_sagas, _from, state) do
    {:reply, {:ok, state.active_sagas}, state}
  end

  @impl true
  def handle_call({:get_saga_state, saga_id}, _from, state) do
    case Map.get(state.active_sagas, saga_id) do
      nil -> {:reply, {:error, :not_found}, state}
      saga_state -> {:reply, {:ok, saga_state}, state}
    end
  end

  @impl true
  def handle_cast({:handle_event, event}, state) do
    # OrderCreatedイベントの場合は新しいSagaを開始
    state =
      case event do
        %Shared.Domain.Events.OrderEvents.OrderCreated{} ->
          case start_saga(CommandService.Domain.Sagas.OrderSaga, event) do
            {:ok, saga_id} ->
              Logger.info("Started OrderSaga #{saga_id} for order #{event.id.value}")
              state

            {:error, reason} ->
              Logger.error("Failed to start OrderSaga: #{inspect(reason)}")
              state
          end

        _ ->
          state
      end

    # 既存のSagaでイベントを処理
    updated_active_sagas =
      Enum.reduce(state.active_sagas, %{}, fn {saga_id, saga_state}, acc ->
        case process_event_for_saga(saga_state, event) do
          {:ok, updated_saga_state} ->
            Map.put(acc, saga_id, updated_saga_state)

          {:remove, final_state} ->
            # 完了または失敗したSagaを削除
            handle_saga_completion(final_state)
            acc

          {:error, _reason} ->
            # エラーの場合は元の状態を保持
            Map.put(acc, saga_id, saga_state)
        end
      end)

    {:noreply, %{state | active_sagas: updated_active_sagas}}
  end

  @impl true
  def handle_info({:event, event}, state) do
    handle_cast({:handle_event, event}, state)
  end

  @impl true
  def handle_info({:step_timeout, saga_id, step_name, compensate_on_timeout}, state) do
    Logger.warning("Step timeout for saga #{saga_id}, step #{step_name}")

    case Map.get(state.active_sagas, saga_id) do
      nil ->
        Logger.warning("Saga #{saga_id} not found in active sagas")
        {:noreply, state}

      saga_state ->
        # タイムアウト状態に更新
        timeout_saga_state = SagaState.timeout(saga_state, step_name)

        # 補償処理を実行するか判断
        updated_saga_state =
          if compensate_on_timeout do
            start_compensation(timeout_saga_state)
          else
            timeout_saga_state
          end

        # 永続化
        SagaRepository.save(updated_saga_state)

        # Telemetry イベント
        :telemetry.execute(
          [:saga, :step_timeout],
          %{},
          %{saga_id: saga_id, step_name: step_name}
        )

        if updated_saga_state.status in [:completed, :failed, :timeout] do
          handle_saga_completion(updated_saga_state)
          updated_active_sagas = Map.delete(state.active_sagas, saga_id)
          {:noreply, %{state | active_sagas: updated_active_sagas}}
        else
          updated_active_sagas = Map.put(state.active_sagas, saga_id, updated_saga_state)
          {:noreply, %{state | active_sagas: updated_active_sagas}}
        end
    end
  end

  # Private functions

  defp restore_active_sagas do
    case SagaRepository.get_active_sagas() do
      {:ok, sagas} ->
        Map.new(sagas, fn saga -> {saga.id, saga} end)

      {:error, _} ->
        %{}
    end
  end

  defp execute_next_step(saga_state) do
    saga_module = saga_state.saga_type
    steps = saga_module.steps()

    # 次のステップを決定
    next_step =
      case saga_state.current_step do
        nil ->
          List.first(steps)

        current ->
          current_index = Enum.find_index(steps, fn s -> s.name == current end)

          if current_index && current_index < length(steps) - 1 do
            Enum.at(steps, current_index + 1)
          else
            nil
          end
      end

    if next_step do
      execute_step(saga_state, next_step)
    else
      # すべてのステップが完了
      completed_state = SagaState.complete(saga_state)
      SagaRepository.save(completed_state)
      completed_state
    end
  end

  defp execute_step(saga_state, step_definition) do
    step_name = step_definition.name
    saga_module = saga_state.saga_type

    Logger.info("Executing step #{step_name} for saga #{saga_state.id}")

    # ステップに必要なリソースロックを取得
    resource_ids = get_step_resources(saga_module, step_name, saga_state)

    lock_result =
      if Enum.any?(resource_ids) do
        SagaLockManager.acquire_resource_locks(saga_state.id, resource_ids, timeout: 10_000)
      else
        {:ok, nil}
      end

    case lock_result do
      {:ok, resource_lock_ref} ->
        try do
          # ステップを開始
          running_state =
            saga_state
            |> SagaState.start_step(step_name)
            |> struct(resource_lock_ref: resource_lock_ref)

          # タイムアウトを設定
          timeout_state =
            case SagaTimeoutManager.start_timeout(
                   saga_state.id,
                   step_name,
                   saga_module,
                   running_state
                 ) do
              {:ok, timer_ref} when is_reference(timer_ref) ->
                SagaState.record_timeout(running_state, step_name, timer_ref)

              {:ok, nil} ->
                running_state

              {:error, _reason} ->
                running_state
            end

          # リトライポリシーを取得
          retry_policy = SagaDefinition.get_retry_policy(saga_module, step_name)

          # ステップをべき等に実行（リトライ付き）
          result =
            IdempotentSaga.execute_step(
              saga_state.id,
              step_name,
              timeout_state,
              fn ->
                if retry_policy do
                  execute_step_with_retry(saga_module, step_name, timeout_state, retry_policy)
                else
                  saga_module.execute_step(step_name, timeout_state)
                end
              end
            )

          case result do
            {:ok, commands} ->
              # コマンドを発行
              Enum.each(commands, &dispatch_command/1)

              # タイムアウトをクリア
              SagaTimeoutManager.cancel_timeout(saga_state.id, step_name)

              # リソースロックを解放
              if resource_lock_ref, do: SagaLockManager.release_lock(resource_lock_ref)

              # ステップを完了
              completed_state = SagaState.complete_step(timeout_state, step_name)
              SagaRepository.save(completed_state)

              # Telemetry イベント
              :telemetry.execute(
                [:saga, :step_completed],
                %{duration: SagaState.get_step_duration(completed_state, step_name)},
                %{saga_id: saga_state.id, step_name: step_name}
              )

              completed_state

            {:error, reason} ->
              # タイムアウトをクリア
              SagaTimeoutManager.cancel_timeout(saga_state.id, step_name)

              # リソースロックを解放
              if resource_lock_ref, do: SagaLockManager.release_lock(resource_lock_ref)

              # ステップが失敗
              failed_state = SagaState.fail_step(timeout_state, step_name, reason)
              SagaRepository.save(failed_state)

              # 補償処理を開始
              start_compensation(failed_state)
          end
        rescue
          e ->
            # リソースロックを解放
            if resource_lock_ref, do: SagaLockManager.release_lock(resource_lock_ref)
            reraise e, __STACKTRACE__
        end

      {:error, :locked} ->
        Logger.warning("Resource lock conflict for saga #{saga_state.id}, step #{step_name}")
        # ロック競合の場合は失敗として扱う
        failed_state = SagaState.fail_step(saga_state, step_name, :resource_locked)
        SagaRepository.save(failed_state)
        start_compensation(failed_state)

      {:error, reason} ->
        Logger.error("Failed to acquire resource locks: #{inspect(reason)}")
        failed_state = SagaState.fail_step(saga_state, step_name, {:lock_error, reason})
        SagaRepository.save(failed_state)
        start_compensation(failed_state)
    end
  end

  defp execute_step_with_retry(saga_module, step_name, saga_state, retry_policy) do
    RetryStrategy.execute_with_condition(
      fn ->
        saga_module.execute_step(step_name, saga_state)
      end,
      fn error ->
        saga_module.can_retry_step?(step_name, error, saga_state)
      end,
      retry_policy
    )
    |> case do
      {:ok, result} ->
        result

      {:error, :max_attempts_exceeded, errors} ->
        # DLQに送信
        DeadLetterQueue.enqueue(
          "saga_step_execution",
          %{
            saga_id: saga_state.id,
            saga_type: saga_module,
            step_name: step_name,
            saga_state: saga_state
          },
          errors,
          %{retry_count: length(errors)}
        )

        {:error, {:max_retries_exceeded, errors}}

      other ->
        other
    end
  end

  defp start_compensation(saga_state) do
    Logger.info("Starting compensation for saga #{saga_state.id}")

    compensating_state = SagaState.start_compensation(saga_state)
    SagaRepository.save(compensating_state)

    # 完了したステップを逆順で補償
    completed_steps = Enum.reverse(compensating_state.completed_steps)

    final_state =
      Enum.reduce_while(completed_steps, compensating_state, fn step_name, acc_state ->
        case compensate_step(acc_state, step_name) do
          {:ok, updated_state} ->
            {:cont, updated_state}

          {:error, updated_state} ->
            {:halt, updated_state}
        end
      end)

    # 補償処理の結果に基づいて最終状態を設定
    if final_state.compensation_state == :failed do
      SagaState.fail_compensation(final_state, :compensation_failed)
    else
      SagaState.complete_compensation(final_state)
    end
  end

  defp compensate_step(saga_state, step_name) do
    saga_module = saga_state.saga_type

    Logger.info("Compensating step #{step_name} for saga #{saga_state.id}")

    # 補償をべき等に実行
    result =
      IdempotentSaga.compensate_step(
        saga_state.id,
        step_name,
        saga_state,
        fn ->
          saga_module.compensate_step(step_name, saga_state)
        end
      )

    case result do
      {:ok, {:ok, commands}} ->
        # 補償コマンドを発行
        Enum.each(commands, &dispatch_command/1)

        # Telemetry イベント
        :telemetry.execute(
          [:saga, :step_compensated],
          %{},
          %{saga_id: saga_state.id, step_name: step_name}
        )

        {:ok, saga_state}

      {:ok, {:error, reason}} ->
        Logger.error("Failed to compensate step #{step_name}: #{inspect(reason)}")

        failed_state = SagaState.fail_compensation(saga_state, reason)
        SagaRepository.save(failed_state)

        {:error, failed_state}

      {:error, reason} ->
        Logger.error("Failed to compensate step #{step_name}: #{inspect(reason)}")

        failed_state = SagaState.fail_compensation(saga_state, reason)
        SagaRepository.save(failed_state)

        {:error, failed_state}
    end
  end

  defp process_event_for_saga(saga_state, event) do
    saga_module = saga_state.saga_type

    # Sagaがイベントを処理できるか確認
    case saga_module.handle_event(event, saga_state) do
      {:ok, updated_data} ->
        # データを更新
        updated_saga_state = SagaState.update_data(saga_state, updated_data)
        SagaRepository.save(updated_saga_state)

        # 次のステップを実行
        next_saga_state = execute_next_step(updated_saga_state)

        # 完了または失敗した場合は削除対象
        if next_saga_state.status in [:completed, :failed] do
          {:remove, next_saga_state}
        else
          {:ok, next_saga_state}
        end

      {:error, _reason} ->
        # このイベントはこのSagaには関係ない
        {:ok, saga_state}

      _ ->
        # 予期しない値の場合
        {:ok, saga_state}
    end
  end

  defp dispatch_command(command) do
    # コマンドディスパッチャーを使用
    dispatcher =
      Application.get_env(
        :shared,
        :saga_command_dispatcher,
        Shared.Infrastructure.Saga.CommandDispatcher
      )

    dispatcher.dispatch_command(command)
  end

  defp handle_saga_completion(saga_state) do
    # 統計を更新
    case saga_state.status do
      :completed ->
        :telemetry.execute(
          [:saga, :completed],
          %{
            duration: DateTime.diff(saga_state.completed_at, saga_state.created_at, :millisecond)
          },
          %{saga_id: saga_state.id, saga_type: saga_state.saga_type}
        )

      :failed ->
        :telemetry.execute(
          [:saga, :failed],
          %{},
          %{
            saga_id: saga_state.id,
            saga_type: saga_state.saga_type,
            reason: saga_state.failure_reason
          }
        )

      _ ->
        :ok
    end

    # すべてのタイムアウトをクリア
    SagaTimeoutManager.cancel_all_timeouts(saga_state.id)

    # すべてのロックを解放
    SagaLockManager.release_saga_locks(saga_state.id)

    # べき等性キーをクリア
    IdempotentSaga.clear_saga_keys(saga_state.id)
  end

  # ステップに必要なリソースIDを取得
  defp get_step_resources(saga_module, step_name, saga_state) do
    # Sagaモジュールがget_step_resourcesを実装している場合はそれを使用
    if function_exported?(saga_module, :get_step_resources, 2) do
      saga_module.get_step_resources(step_name, saga_state)
    else
      # デフォルトではリソースロックなし
      []
    end
  end
end
