defmodule Shared.Infrastructure.Saga.SagaLockManager do
  @moduledoc """
  Sagaインスタンスのロック機構を提供し、並行性制御と重複実行を防止する

  ## 機能
  - Sagaインスタンスの排他ロック
  - リソースレベルのロック順序制御
  - デッドロック検出と回避
  - タイムアウト付きロック取得
  """

  use GenServer
  require Logger

  # 30秒
  @default_lock_timeout 30_000
  # 5秒
  @deadlock_detection_interval 5_000

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sagaインスタンスのロックを取得
  """
  @spec acquire_saga_lock(String.t(), keyword()) ::
          {:ok, reference()} | {:error, :locked | :timeout}
  def acquire_saga_lock(saga_id, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_lock_timeout)
    owner = Keyword.get(opts, :owner, self())

    GenServer.call(__MODULE__, {:acquire_saga_lock, saga_id, owner, timeout}, timeout + 1000)
  end

  @doc """
  リソースロックを取得（順序付きで取得してデッドロックを防止）
  """
  @spec acquire_resource_locks(String.t(), [String.t()], keyword()) ::
          {:ok, reference()} | {:error, :locked | :timeout | :deadlock}
  def acquire_resource_locks(saga_id, resource_ids, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_lock_timeout)
    owner = Keyword.get(opts, :owner, self())

    # リソースIDをソートして順序を固定（デッドロック防止）
    sorted_resources = Enum.sort(resource_ids)

    GenServer.call(
      __MODULE__,
      {:acquire_resource_locks, saga_id, sorted_resources, owner, timeout},
      timeout + 1000
    )
  end

  @doc """
  ロックを解放
  """
  @spec release_lock(reference()) :: :ok
  def release_lock(lock_ref) do
    GenServer.cast(__MODULE__, {:release_lock, lock_ref})
  end

  @doc """
  Sagaに関連するすべてのロックを解放
  """
  @spec release_saga_locks(String.t()) :: :ok
  def release_saga_locks(saga_id) do
    GenServer.cast(__MODULE__, {:release_saga_locks, saga_id})
  end

  @doc """
  プロセス終了時の自動ロック解放を設定
  """
  @spec monitor_lock_owner(pid()) :: :ok
  def monitor_lock_owner(owner_pid) do
    GenServer.cast(__MODULE__, {:monitor_owner, owner_pid})
  end

  @doc """
  現在のロック状態を取得
  """
  @spec get_lock_status() :: {:ok, map()}
  def get_lock_status do
    GenServer.call(__MODULE__, :get_lock_status)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # デッドロック検出タイマーを開始
    Process.send_after(self(), :detect_deadlocks, @deadlock_detection_interval)

    state = %{
      # saga_id -> lock_info
      saga_locks: %{},
      # resource_id -> lock_info
      resource_locks: %{},
      # lock_ref -> lock_details
      lock_registry: %{},
      # owner_pid -> [lock_refs]
      owner_locks: %{},
      # モニタリング情報
      monitors: %{},
      # 統計情報
      stats: %{
        acquired: 0,
        released: 0,
        timeouts: 0,
        conflicts: 0,
        deadlocks_detected: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:acquire_saga_lock, saga_id, owner, timeout}, from, state) do
    case Map.get(state.saga_locks, saga_id) do
      nil ->
        # ロックが利用可能
        lock_ref = make_ref()

        lock_info = %{
          ref: lock_ref,
          owner: owner,
          saga_id: saga_id,
          type: :saga,
          acquired_at: DateTime.utc_now(),
          from: from
        }

        # ロックを記録
        state =
          state
          |> put_in([:saga_locks, saga_id], lock_info)
          |> put_in([:lock_registry, lock_ref], lock_info)
          |> update_in([:owner_locks, owner], fn locks ->
            [lock_ref | locks || []]
          end)
          |> update_in([:stats, :acquired], &(&1 + 1))

        # オーナーをモニター
        state = monitor_owner(state, owner)

        # タイムアウトタイマーを設定
        timer_ref = Process.send_after(self(), {:lock_timeout, lock_ref}, timeout)
        state = put_in(state, [:lock_registry, lock_ref, :timer], timer_ref)

        Logger.debug("Acquired saga lock: #{saga_id} for owner: #{inspect(owner)}")

        :telemetry.execute(
          [:saga, :lock, :acquired],
          %{},
          %{saga_id: saga_id, lock_type: :saga}
        )

        {:reply, {:ok, lock_ref}, state}

      %{owner: ^owner} ->
        # 同じオーナーが既にロックを保持（再入可能）
        {:reply, {:ok, state.saga_locks[saga_id].ref}, state}

      _existing_lock ->
        # 他のプロセスがロックを保持
        state = update_in(state, [:stats, :conflicts], &(&1 + 1))

        Logger.debug("Saga lock conflict: #{saga_id}")

        :telemetry.execute(
          [:saga, :lock, :conflict],
          %{},
          %{saga_id: saga_id, lock_type: :saga}
        )

        {:reply, {:error, :locked}, state}
    end
  end

  @impl true
  def handle_call({:acquire_resource_locks, saga_id, resource_ids, owner, timeout}, from, state) do
    # すべてのリソースが利用可能かチェック
    conflicts =
      Enum.filter(resource_ids, fn resource_id ->
        case Map.get(state.resource_locks, resource_id) do
          nil -> false
          # 同じSagaの同じオーナー
          %{owner: ^owner, saga_id: ^saga_id} -> false
          _ -> true
        end
      end)

    if Enum.empty?(conflicts) do
      # すべてのリソースが利用可能
      lock_ref = make_ref()
      acquired_at = DateTime.utc_now()

      # 各リソースにロックを設定
      {state, _lock_infos} =
        Enum.reduce(resource_ids, {state, []}, fn resource_id, {acc_state, acc_infos} ->
          lock_info = %{
            ref: lock_ref,
            owner: owner,
            saga_id: saga_id,
            resource_id: resource_id,
            type: :resource,
            acquired_at: acquired_at,
            from: from
          }

          updated_state = put_in(acc_state, [:resource_locks, resource_id], lock_info)
          {updated_state, [lock_info | acc_infos]}
        end)

      # 統合ロック情報
      combined_lock_info = %{
        ref: lock_ref,
        owner: owner,
        saga_id: saga_id,
        resource_ids: resource_ids,
        type: :resource_group,
        acquired_at: acquired_at,
        from: from
      }

      state =
        state
        |> put_in([:lock_registry, lock_ref], combined_lock_info)
        |> update_in([:owner_locks, owner], fn locks ->
          [lock_ref | locks || []]
        end)
        |> update_in([:stats, :acquired], &(&1 + length(resource_ids)))

      # オーナーをモニター
      state = monitor_owner(state, owner)

      # タイムアウトタイマーを設定
      timer_ref = Process.send_after(self(), {:lock_timeout, lock_ref}, timeout)
      state = put_in(state, [:lock_registry, lock_ref, :timer], timer_ref)

      Logger.debug("Acquired resource locks: #{inspect(resource_ids)} for saga: #{saga_id}")

      :telemetry.execute(
        [:saga, :lock, :acquired],
        %{count: length(resource_ids)},
        %{saga_id: saga_id, lock_type: :resource_group}
      )

      {:reply, {:ok, lock_ref}, state}
    else
      # リソースの競合
      state = update_in(state, [:stats, :conflicts], &(&1 + 1))

      Logger.debug("Resource lock conflict: #{inspect(conflicts)} for saga: #{saga_id}")

      :telemetry.execute(
        [:saga, :lock, :conflict],
        %{conflict_count: length(conflicts)},
        %{saga_id: saga_id, lock_type: :resource_group}
      )

      {:reply, {:error, :locked}, state}
    end
  end

  @impl true
  def handle_call(:get_lock_status, _from, state) do
    status = %{
      saga_locks: map_size(state.saga_locks),
      resource_locks: map_size(state.resource_locks),
      active_locks: map_size(state.lock_registry),
      monitored_owners: map_size(state.monitors),
      stats: state.stats
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_cast({:release_lock, lock_ref}, state) do
    state = release_lock_internal(state, lock_ref)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:release_saga_locks, saga_id}, state) do
    # 該当するSagaのすべてのロックを解放
    locks_to_release =
      state.lock_registry
      |> Enum.filter(fn {_ref, info} -> info[:saga_id] == saga_id end)
      |> Enum.map(fn {ref, _info} -> ref end)

    state =
      Enum.reduce(locks_to_release, state, fn lock_ref, acc_state ->
        release_lock_internal(acc_state, lock_ref)
      end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:monitor_owner, owner_pid}, state) do
    state = monitor_owner(state, owner_pid)
    {:noreply, state}
  end

  @impl true
  def handle_info({:lock_timeout, lock_ref}, state) do
    Logger.warning("Lock timeout: #{inspect(lock_ref)}")

    state =
      state
      |> release_lock_internal(lock_ref)
      |> update_in([:stats, :timeouts], &(&1 + 1))

    :telemetry.execute(
      [:saga, :lock, :timeout],
      %{},
      %{lock_ref: lock_ref}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, owner_pid, _reason}, state) do
    Logger.info("Lock owner process died: #{inspect(owner_pid)}")

    # オーナーが保持していたすべてのロックを解放
    locks_to_release = Map.get(state.owner_locks, owner_pid, [])

    state =
      locks_to_release
      |> Enum.reduce(state, fn lock_ref, acc_state ->
        release_lock_internal(acc_state, lock_ref)
      end)
      |> update_in([:monitors], &Map.delete(&1, monitor_ref))
      |> update_in([:owner_locks], &Map.delete(&1, owner_pid))

    {:noreply, state}
  end

  @impl true
  def handle_info(:detect_deadlocks, state) do
    # デッドロック検出ロジック（簡易版）
    # TODO: より高度なデッドロック検出アルゴリズムの実装

    # 次回の検出をスケジュール
    Process.send_after(self(), :detect_deadlocks, @deadlock_detection_interval)

    {:noreply, state}
  end

  # Private functions

  defp release_lock_internal(state, lock_ref) do
    case Map.get(state.lock_registry, lock_ref) do
      nil ->
        state

      lock_info ->
        # タイマーをキャンセル
        if timer = lock_info[:timer] do
          Process.cancel_timer(timer)
        end

        # ロックを解放
        state =
          case lock_info.type do
            :saga ->
              update_in(state, [:saga_locks], &Map.delete(&1, lock_info.saga_id))

            :resource ->
              update_in(state, [:resource_locks], &Map.delete(&1, lock_info.resource_id))

            :resource_group ->
              Enum.reduce(lock_info.resource_ids, state, fn resource_id, acc_state ->
                update_in(acc_state, [:resource_locks], &Map.delete(&1, resource_id))
              end)
          end

        # レジストリから削除
        state =
          state
          |> update_in([:lock_registry], &Map.delete(&1, lock_ref))
          |> update_in([:owner_locks, lock_info.owner], fn locks ->
            List.delete(locks || [], lock_ref)
          end)
          |> update_in([:stats, :released], &(&1 + 1))

        Logger.debug("Released lock: #{inspect(lock_ref)}")

        :telemetry.execute(
          [:saga, :lock, :released],
          %{},
          %{lock_ref: lock_ref, lock_type: lock_info.type}
        )

        state
    end
  end

  defp monitor_owner(state, owner_pid) when is_pid(owner_pid) do
    case Process.info(owner_pid) do
      nil ->
        # プロセスが既に存在しない
        state

      _ ->
        # まだモニターしていない場合のみモニターを開始
        if Enum.any?(state.monitors, fn {_ref, pid} -> pid == owner_pid end) do
          state
        else
          monitor_ref = Process.monitor(owner_pid)
          put_in(state, [:monitors, monitor_ref], owner_pid)
        end
    end
  end

  defp monitor_owner(state, _owner), do: state
end
