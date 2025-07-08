defmodule Shared.Infrastructure.Saga.SagaCoordinator do
  @moduledoc """
  サガの実行を調整するコーディネーター

  サガのライフサイクルを管理し、イベントの処理、
  コマンドの発行、補償処理の実行を担当します。
  """

  use GenServer
  require Logger

  alias Shared.Domain.Saga.SagaEvents
  alias Shared.Infrastructure.EventStore
  alias Shared.Infrastructure.Saga.SagaRepository

  # 30秒ごとにタイムアウトチェック
  @timeout_check_interval 30_000
  # デフォルトは5分
  @default_saga_timeout 300_000

  # Client API

  @doc """
  サガコーディネーターを開始する
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  新しいサガを開始する
  """
  @spec start_saga(module(), map(), map()) :: {:ok, String.t()} | {:error, any()}
  def start_saga(saga_module, initial_data, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:start_saga, saga_module, initial_data, metadata})
  end

  @doc """
  イベントを処理する
  """
  @spec process_event(map()) :: :ok
  def process_event(event) do
    GenServer.cast(__MODULE__, {:process_event, event})
  end

  @doc """
  アクティブなサガの一覧を取得する
  """
  @spec list_active_sagas() :: [map()]
  def list_active_sagas do
    GenServer.call(__MODULE__, :list_active_sagas)
  end

  @doc """
  サガの状態を取得する
  """
  @spec get_saga(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_saga(saga_id) do
    GenServer.call(__MODULE__, {:get_saga, saga_id})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # タイムアウトチェックのタイマーを開始
    schedule_timeout_check()

    state = %{
      active_sagas: %{},
      saga_modules: register_saga_modules(opts[:saga_modules] || []),
      timeout_check_ref: nil
    }

    # 既存のアクティブなサガを復元
    restore_active_sagas(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:start_saga, saga_module, initial_data, metadata}, _from, state) do
    saga_id = UUID.uuid4()

    # サガを初期化
    try do
      saga = saga_module.start(saga_id, initial_data)

      # 開始イベントを発行
      event = SagaEvents.SagaStarted.new(saga_id, saga.saga_type, initial_data, metadata)

      case persist_saga_event(event) do
        :ok ->
          # サガを永続化
          case SagaRepository.save(saga) do
            {:ok, _} ->
              # アクティブなサガとして登録
              new_state =
                put_in(state.active_sagas[saga_id], %{
                  module: saga_module,
                  saga: saga
                })

              # 初期コマンドを処理
              handle_initial_commands(saga_module, saga)

              {:reply, {:ok, saga_id}, new_state}

            {:error, reason} = error ->
              Logger.error("Failed to save saga: #{inspect(reason)}")
              {:reply, error, state}
          end

        {:error, reason} = error ->
          Logger.error("Failed to persist saga started event: #{inspect(reason)}")
          {:reply, error, state}
      end
    rescue
      error ->
        Logger.error("Failed to start saga: #{inspect(error)}")
        {:reply, {:error, :saga_start_failed}, state}
    end
  end

  @impl true
  def handle_call(:list_active_sagas, _from, state) do
    sagas =
      Enum.map(state.active_sagas, fn {id, %{saga: saga}} ->
        Map.put(saga, :id, id)
      end)

    {:reply, sagas, state}
  end

  @impl true
  def handle_call({:get_saga, saga_id}, _from, state) do
    case Map.get(state.active_sagas, saga_id) do
      nil ->
        # 永続化ストアから取得を試みる
        case SagaRepository.get(saga_id) do
          {:ok, saga} -> {:reply, {:ok, saga}, state}
          {:error, _} -> {:reply, {:error, :not_found}, state}
        end

      %{saga: saga} ->
        {:reply, {:ok, saga}, state}
    end
  end

  @impl true
  def handle_cast({:process_event, event}, state) do
    # イベントに関連するサガを見つける
    case find_interested_sagas(event, state) do
      [] ->
        {:noreply, state}

      interested_sagas ->
        new_state =
          Enum.reduce(interested_sagas, state, fn {saga_id, saga_info}, acc_state ->
            process_event_for_saga(event, saga_id, saga_info, acc_state)
          end)

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:check_timeouts, state) do
    # タイムアウトしたサガをチェック
    new_state = check_and_handle_timeouts(state)

    # 次のチェックをスケジュール
    schedule_timeout_check()

    {:noreply, new_state}
  end

  # Private functions

  defp register_saga_modules(modules) do
    Enum.reduce(modules, %{}, fn module, acc ->
      saga_type = module |> Module.split() |> List.last()
      Map.put(acc, saga_type, module)
    end)
  end

  defp restore_active_sagas(state) do
    case SagaRepository.list_active() do
      {:ok, sagas} ->
        Enum.each(sagas, fn saga ->
          saga_module = Map.get(state.saga_modules, saga.saga_type)

          if saga_module do
            put_in(state.active_sagas[saga.saga_id], %{
              module: saga_module,
              saga: saga
            })
          end
        end)

      {:error, reason} ->
        Logger.error("Failed to restore active sagas: #{inspect(reason)}")
    end
  end

  defp handle_initial_commands(saga_module, saga) do
    # サガの初期イベントを処理
    case saga_module.handle_event(%{event_type: "saga_started"}, saga) do
      {:ok, commands} ->
        dispatch_commands(commands, saga.saga_id)

      {:error, reason} ->
        Logger.error("Failed to handle initial saga event: #{inspect(reason)}")
    end
  end

  defp find_interested_sagas(event, state) do
    # イベントのmetadataからsaga_idを取得
    saga_id = get_in(event, [:metadata, :saga_id])

    if saga_id && Map.has_key?(state.active_sagas, saga_id) do
      [{saga_id, Map.get(state.active_sagas, saga_id)}]
    else
      # 新しいサガを開始すべきイベントかチェック
      check_saga_triggers(event, state)
    end
  end

  defp check_saga_triggers(event, state) do
    # イベントタイプに基づいて新しいサガを開始するロジック
    event_type = Map.get(event, :event_type)

    # 各サガモジュールのトリガーイベントをチェック
    Enum.reduce(state.saga_modules, [], fn {saga_type, saga_module}, acc ->
      if function_exported?(saga_module, :trigger_events, 0) do
        trigger_events = saga_module.trigger_events()

        if event_type in trigger_events do
          # サガを開始すべき場合
          saga_id = UUID.uuid4()
          initial_data = extract_initial_data(event, saga_module)

          # 新しいサガを作成してstateに保存し、対象サガのリストに追加
          try do
            saga = saga_module.start(saga_id, initial_data)

            # サガ開始イベントを発行
            start_event =
              SagaEvents.SagaStarted.new(
                saga_id,
                saga_module |> Module.split() |> List.last(),
                initial_data,
                %{triggered_by: event.event_id}
              )

            persist_saga_event(start_event)

            # サガ情報を作成
            saga_info = %{
              module: saga_module,
              saga: saga,
              started_at: DateTime.utc_now()
            }

            # stateを更新（handle_castで行うため、ここでは単にリストに追加）
            [{saga_id, saga_info} | acc]
          rescue
            error ->
              Logger.error("Failed to trigger saga",
                saga_type: saga_type,
                trigger_event: event_type,
                error: inspect(error)
              )

              acc
          end
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp extract_initial_data(event, saga_module) do
    # サガモジュールが初期データ抽出関数を持っている場合は使用
    if function_exported?(saga_module, :extract_initial_data, 1) do
      saga_module.extract_initial_data(event)
    else
      # デフォルト: イベントのペイロードを使用
      Map.get(event, :payload, %{})
    end
  end

  defp start_saga_internal(saga_module, saga_id, initial_data, metadata, state) do
    saga = saga_module.new(saga_id, initial_data)

    # サガ開始イベントを発行
    event =
      SagaEvents.SagaStarted.new(
        saga_id,
        saga_module |> Module.split() |> List.last(),
        initial_data,
        metadata
      )

    case EventStore.append_to_stream("saga-#{saga_id}", [event], 0) do
      {:ok, _} ->
        # メモリに保存
        new_state =
          put_in(state.active_sagas[saga_id], %{
            module: saga_module,
            saga: saga,
            started_at: DateTime.utc_now()
          })

        # 持続化
        SagaRepository.save(saga)

        # 最初のステップを実行
        updated_state = process_next_step(saga_id, saga, saga_module, new_state)
        {:ok, updated_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_next_step(saga_id, saga, saga_module, state) do
    # サガの次のステップを実行
    case saga_module.next_step(saga) do
      {:ok, commands} when is_list(commands) and length(commands) > 0 ->
        # コマンドを発行
        dispatch_commands(commands, saga_id)
        state

      {:ok, []} ->
        # すべてのステップが完了
        complete_saga(saga_id, saga, saga_module, state)

      {:error, reason} ->
        Logger.error("Failed to determine next step for saga",
          saga_id: saga_id,
          saga_type: saga_module,
          error: inspect(reason)
        )

        handle_saga_failure(saga, saga_module, saga_id, "next_step", reason, state)
    end
  end

  defp process_event_for_saga(event, saga_id, saga_info, state) do
    %{module: saga_module, saga: saga} = saga_info

    # 新しく作成されたサガの場合、まずstateに追加
    state_with_saga =
      if Map.has_key?(state.active_sagas, saga_id) do
        state
      else
        put_in(state, [:active_sagas, saga_id], saga_info)
      end

    # 既に処理済みのイベントかチェック
    if already_processed?(saga, event) do
      state_with_saga
    else
      case saga_module.handle_event(event, saga) do
        {:ok, commands} ->
          # サガの状態を更新
          updated_saga =
            saga
            |> saga_module.mark_event_processed(event)
            |> update_saga_state_from_event(event, saga_module)

          # コマンドを発行
          dispatch_commands(commands, saga_id)

          # ステップ完了イベントを記録
          record_step_completion(saga_id, event.event_type)

          # サガを永続化
          case SagaRepository.save(updated_saga) do
            {:ok, _} ->
              # stateのサガ情報を更新
              updated_state =
                put_in(state_with_saga, [:active_sagas, saga_id, :saga], updated_saga)

              # サガが完了または失敗したかチェック
              handle_saga_completion(updated_saga, saga_module, saga_id, updated_state)

            {:error, reason} ->
              Logger.error("Failed to save saga: #{inspect(reason)}")
              state_with_saga
          end

        {:error, reason} ->
          handle_saga_failure(
            saga,
            saga_module,
            saga_id,
            event.event_type,
            reason,
            state_with_saga
          )
      end
    end
  end

  defp already_processed?(saga, event) do
    Enum.any?(saga.processed_events, fn {event_id, _} -> event_id == event.event_id end)
  end

  defp update_saga_state_from_event(saga, event, saga_module) do
    cond do
      success_event?(event) ->
        saga_module.mark_step_completed(saga, event.event_type, event.payload)

      failure_event?(event) ->
        saga_module.mark_failed(saga, event.event_type, event.payload)

      true ->
        saga
    end
  end

  defp success_event?(event) do
    String.ends_with?(event.event_type, "_succeeded") ||
      String.ends_with?(event.event_type, "_completed")
  end

  defp failure_event?(event) do
    String.ends_with?(event.event_type, "_failed") ||
      String.ends_with?(event.event_type, "_rejected")
  end

  defp dispatch_commands(commands, saga_id) do
    Enum.each(commands, fn command ->
      # コマンドにsaga_idを追加
      existing_metadata = Map.get(command, :metadata, %{})

      command_with_saga =
        Map.put(command, :metadata, Map.put(existing_metadata, :saga_id, saga_id))

      # コマンドバスに送信
      case dispatch_command(command_with_saga) do
        {:ok, _} ->
          Logger.info(
            "Dispatched command for saga #{saga_id}: #{inspect(Map.get(command, :type, "unknown"))}"
          )

        {:error, reason} ->
          Logger.error("Failed to dispatch command for saga #{saga_id}: #{inspect(reason)}")
      end
    end)
  end

  defp dispatch_command(command) do
    # 設定されたコマンドディスパッチャーを使用
    dispatcher =
      Application.get_env(
        :shared,
        :command_dispatcher,
        Shared.Infrastructure.Saga.CommandDispatcher
      )

    case dispatcher.dispatch(command) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} = error ->
        Logger.error("Failed to dispatch command: #{inspect(reason)}")
        error
    end
  end

  defp record_step_completion(saga_id, step_name) do
    event = SagaEvents.SagaStepCompleted.new(saga_id, step_name, %{})
    persist_saga_event(event)
  end

  defp handle_saga_completion(saga, saga_module, saga_id, state) do
    cond do
      saga_module.completed?(saga) ->
        # 完了イベントを発行
        event = SagaEvents.SagaCompleted.new(saga_id, saga.data)
        persist_saga_event(event)

        # アクティブリストから削除
        {_, new_state} = pop_in(state.active_sagas[saga_id])
        new_state

      saga_module.failed?(saga) ->
        # 補償処理を開始
        start_compensation(saga, saga_module, saga_id, state)

      true ->
        # 更新されたサガを保持
        put_in(state.active_sagas[saga_id].saga, saga)
    end
  end

  defp handle_saga_failure(saga, saga_module, saga_id, failed_step, reason, state) do
    # 失敗イベントを記録
    event = SagaEvents.SagaFailed.new(saga_id, failed_step, reason)
    persist_saga_event(event)

    # サガを失敗状態に更新
    failed_saga = saga_module.mark_failed(saga, failed_step, reason)

    # 補償処理を開始
    start_compensation(failed_saga, saga_module, saga_id, state)
  end

  defp complete_saga(saga_id, saga, _saga_module, state) do
    # 完了イベントを発行
    event = SagaEvents.SagaCompleted.new(saga_id, saga.data)
    persist_saga_event(event)

    # アーカイブ
    SagaRepository.archive_completed_saga(saga_id)

    # アクティブリストから削除
    {_, new_state} = pop_in(state.active_sagas[saga_id])
    new_state
  end

  defp start_compensation(saga, saga_module, saga_id, state) do
    # 補償開始イベントを記録
    event = SagaEvents.SagaCompensationStarted.new(saga_id)
    persist_saga_event(event)

    # 補償コマンドを取得
    compensation_commands = saga_module.get_compensation_commands(saga)

    # 補償処理を開始
    compensating_saga = saga_module.start_compensation(saga)

    # 補償コマンドを発行
    dispatch_commands(compensation_commands, saga_id)

    # 状態を更新
    put_in(state.active_sagas[saga_id].saga, compensating_saga)
  end

  defp schedule_timeout_check do
    Process.send_after(self(), :check_timeouts, @timeout_check_interval)
  end

  defp check_and_handle_timeouts(state) do
    Enum.reduce(state.active_sagas, state, fn {saga_id, %{module: saga_module, saga: saga}},
                                              acc_state ->
      timeout = saga.timeout || @default_saga_timeout

      if saga_module.timed_out?(saga, timeout) do
        Logger.warning("Saga #{saga_id} timed out")
        handle_saga_failure(saga, saga_module, saga_id, "timeout", "Saga timed out", acc_state)
      else
        acc_state
      end
    end)
  end

  defp persist_saga_event(event) do
    saga_id = event.aggregate_id
    stream_name = "saga-#{saga_id}"

    case EventStore.append_to_stream(stream_name, [event], :any) do
      {:ok, _} ->
        Logger.debug("Saga event persisted",
          saga_id: saga_id,
          event_type: event.event_type
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to persist saga event",
          saga_id: saga_id,
          event_type: event.event_type,
          error: inspect(reason)
        )

        {:error, reason}
    end
  end
end
