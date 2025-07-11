defmodule Shared.Infrastructure.Saga.SagaCoordinator do
  @moduledoc """
  サガコーディネーター

  サガの実行を調整し、イベントとコマンドの処理を管理します
  """

  use GenServer

  alias Shared.Infrastructure.EventBus

  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  新しいサガを開始する
  """
  def start_saga(saga_id, saga_module, initial_data) do
    GenServer.call(__MODULE__, {:start_saga, saga_id, saga_module, initial_data})
  end

  @doc """
  イベントを処理する
  """
  def handle_event(event) do
    GenServer.cast(__MODULE__, {:handle_event, event})
  end

  @doc """
  アクティブなサガを取得する
  """
  def get_active_sagas do
    GenServer.call(__MODULE__, :get_active_sagas)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # イベントバスに登録
    EventBus.subscribe_all()

    # アクティブなSAGAを復元
    active_sagas = restore_active_sagas()

    state = %{
      # saga_id => {saga_module, saga_state}
      active_sagas: active_sagas,
      # event_type => [saga_modules]
      saga_mappings: %{
        :order_created => [CommandService.Domain.Sagas.OrderSaga],
        "order_created" => [CommandService.Domain.Sagas.OrderSaga]
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_saga, saga_id, saga_module, initial_data}, _from, state) do
    saga_state = saga_module.new(saga_id, initial_data)

    # サガを保存
    new_active_sagas = Map.put(state.active_sagas, saga_id, {saga_module, saga_state})
    persist_saga(saga_id, saga_state)

    # 初期コマンドを発行
    case get_next_commands(saga_state) do
      {:ok, commands} ->
        Enum.each(commands, &dispatch_command/1)
        {:reply, {:ok, saga_id}, %{state | active_sagas: new_active_sagas}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_active_sagas, _from, state) do
    {:reply, state.active_sagas, state}
  end

  @impl true
  def handle_cast({:handle_event, event}, state) do
    # イベントタイプからサガを特定
    event_type = get_event_type(event)

    # 新しいサガを開始すべきかチェック
    new_state =
      if saga_modules = state.saga_mappings[event_type] do
        Enum.reduce(saga_modules, state, fn saga_module, acc_state ->
          start_new_saga_if_needed(saga_module, event, acc_state)
        end)
      else
        state
      end

    # 既存のサガでイベントを処理
    updated_state =
      Enum.reduce(new_state.active_sagas, new_state, fn {saga_id, {saga_module, saga_state}},
                                                        acc_state ->
        # saga_id がイベントの saga_id と一致するかチェック
        if Map.get(event, :saga_id) == saga_id do
          case saga_module.handle_event(event, saga_state) do
            {:ok, commands} ->
              # コマンドを発行
              Enum.each(commands, &dispatch_command/1)

              # handle_event内で更新されたsaga_stateを取得
              # (本来はhandle_eventが更新されたsaga_stateを返すべきだが、現在はコマンドのみ返している)
              # そのため、イベントに基づいて手動で更新する必要がある
              updated_saga_state = apply_event_to_saga(saga_module, saga_state, event)

              # 完了または失敗したサガをチェック
              if saga_module.completed?(updated_saga_state) or
                   saga_module.failed?(updated_saga_state) do
                # サガを永続化してアクティブリストから削除
                persist_saga(saga_id, updated_saga_state)
                %{acc_state | active_sagas: Map.delete(acc_state.active_sagas, saga_id)}
              else
                # サガの状態を更新して永続化
                persist_saga(saga_id, updated_saga_state)
                %{
                  acc_state
                  | active_sagas:
                      Map.put(acc_state.active_sagas, saga_id, {saga_module, updated_saga_state})
                }
              end

            {:error, _reason} ->
              # エラーをログに記録
              Logger.error("Saga #{saga_id} failed to handle event: #{inspect(event)}")
              acc_state
          end
        else
          acc_state
        end
      end)

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:event, event_type, event}, state) do
    # コマンド、クエリ、レスポンスイベントは無視する
    if event_type in [:commands, :queries, :command_responses_client_at_127_0_0_1] do
      {:noreply, state}
    else
      # EventBus からのイベントを処理
      handle_cast({:handle_event, event}, state)
    end
  end

  @impl true
  def handle_info({:event, event}, state) do
    # 新しい形式のイベント
    handle_cast({:handle_event, event}, state)
  end

  # Private functions

  defp get_event_type(event) do
    cond do
      # コマンドレスポンスの場合はスキップ
      Map.has_key?(event, :request_id) and Map.has_key?(event, :result) ->
        nil

      is_map(event) and Map.has_key?(event, :__struct__) and function_exported?(event.__struct__, :event_type, 0) ->
        event.__struct__.event_type()

      Map.has_key?(event, :event_type) ->
        event.event_type

      true ->
        nil
    end
  end

  defp start_new_saga_if_needed(saga_module, event, state) do
    # OrderCreated イベントの場合、新しい OrderSaga を開始
    if match?(%Shared.Domain.Events.OrderEvents.OrderCreated{}, event) do
      initial_data = %{
        order_id: event.id.value,
        user_id: event.user_id.value,
        items: event.items,
        total_amount: event.total_amount
      }

      saga_id = event.saga_id.value
      saga_state = saga_module.new(saga_id, initial_data)

      # 最初のコマンドを発行
      case get_next_commands(saga_state) do
        {:ok, commands} ->
          Enum.each(commands, &dispatch_command/1)
          %{state | active_sagas: Map.put(state.active_sagas, saga_id, {saga_module, saga_state})}

        {:error, _reason} ->
          state
      end
    else
      state
    end
  end

  defp get_next_commands(saga_state) do
    # 現在のステップに基づいて次のコマンドを生成
    case saga_state.current_step do
      :reserve_inventory ->
        commands =
          Enum.map(saga_state.items, fn item ->
            %{
              command_type: "reserve_inventory",
              order_id: saga_state.order_id,
              product_id: item.product_id,
              quantity: item.quantity,
              saga_id: saga_state.saga_id
            }
          end)

        {:ok, commands}

      _ ->
        {:ok, []}
    end
  end

  defp update_saga_state_from_event(saga_state, event) do
    # イベントの情報でサガの状態を更新
    saga_state
    |> Map.put(:updated_at, DateTime.utc_now())
    |> Map.update(:processed_events, [event.__struct__], &[event.__struct__ | &1])
  end

  defp apply_event_to_saga(saga_module, saga_state, event) do
    # OrderSagaの場合の特別な処理
    if saga_module == CommandService.Domain.Sagas.OrderSaga do
      case {saga_state.current_step, event.__struct__} do
        {:reserve_inventory, Shared.Domain.Events.SagaEvents.InventoryReserved} ->
          saga_state
          |> Map.put(:inventory_reserved, true)
          |> Map.put(:reservation_ids, Enum.map(event.items, & &1.product_id))
          |> Map.put(:current_step, :process_payment)
          |> Map.update(:completed_steps, [:reserve_inventory], &[:reserve_inventory | &1])
          |> Map.put(:updated_at, DateTime.utc_now())

        {:process_payment, Shared.Domain.Events.SagaEvents.PaymentProcessed} ->
          saga_state
          |> Map.put(:payment_processed, true)
          |> Map.put(:payment_id, event.transaction_id)
          |> Map.put(:current_step, :arrange_shipping)
          |> Map.update(:completed_steps, [:process_payment], &[:process_payment | &1])
          |> Map.put(:updated_at, DateTime.utc_now())

        {:arrange_shipping, Shared.Domain.Events.SagaEvents.ShippingArranged} ->
          saga_state
          |> Map.put(:shipping_arranged, true)
          |> Map.put(:shipping_id, event.shipping_id)
          |> Map.put(:current_step, :confirm_order)
          |> Map.update(:completed_steps, [:arrange_shipping], &[:arrange_shipping | &1])
          |> Map.put(:updated_at, DateTime.utc_now())

        {:confirm_order, Shared.Domain.Events.SagaEvents.OrderConfirmed} ->
          saga_state
          |> Map.put(:order_confirmed, true)
          |> Map.put(:state, :completed)
          |> Map.update(:completed_steps, [:confirm_order], &[:confirm_order | &1])
          |> Map.put(:updated_at, DateTime.utc_now())

        # エラーイベントの処理
        {step, _} when step == :reserve_inventory ->
          if event.__struct__ == Shared.Domain.Events.SagaEvents.InventoryReservationFailed do
            saga_state
            |> Map.put(:state, :failed)
            |> Map.put(:failed_step, step)
            |> Map.put(:failure_reason, event.reason)
            |> Map.put(:failed_at, DateTime.utc_now())
          else
            saga_state
          end

        {step, _} when step == :process_payment ->
          if event.__struct__ == Shared.Domain.Events.SagaEvents.PaymentFailed do
            saga_state
            |> Map.put(:state, :failed)
            |> Map.put(:failed_step, step)
            |> Map.put(:failure_reason, event.reason)
            |> Map.put(:failed_at, DateTime.utc_now())
          else
            saga_state
          end

        _ ->
          saga_state
      end
    else
      update_saga_state_from_event(saga_state, event)
    end
  end

  defp dispatch_command(command) do
    # コマンドをコマンドバスに送信
    Logger.info("Dispatching command: #{inspect(command)}")

    # コマンドディスパッチャーを使用
    dispatcher =
      Application.get_env(
        :shared,
        :saga_command_dispatcher,
        Shared.Infrastructure.Saga.CommandDispatcher
      )

    dispatcher.dispatch_command(command)
  end

  defp persist_saga(saga_id, saga_state) do
    # サガの最終状態を永続化
    Logger.info("Persisting saga #{saga_id} with state: #{saga_state.state}")

    alias Shared.Infrastructure.Saga.SagaRepository
    SagaRepository.save_saga(saga_id, saga_state)
  end

  defp restore_active_sagas() do
    Logger.info("Restoring active sagas...")
    
    alias Shared.Infrastructure.Saga.SagaRepository
    
    case SagaRepository.get_active_sagas() do
      {:ok, sagas} ->
        Enum.reduce(sagas, %{}, fn saga_data, acc ->
          saga_id = saga_data.saga_id
          saga_type = saga_data.saga_type
          saga_state = saga_data.state
          
          # SAGA typeからmoduleを決定
          saga_module = case saga_type do
            "OrderSaga" -> CommandService.Domain.Sagas.OrderSaga
            _ -> nil
          end
          
          if saga_module do
            Logger.info("Restored saga: #{inspect(saga_id)} (#{saga_type})")
            Map.put(acc, saga_id, {saga_module, saga_state})
          else
            Logger.warning("Unknown saga type: #{saga_type}")
            acc
          end
        end)
        
      {:error, reason} ->
        Logger.error("Failed to restore sagas: #{inspect(reason)}")
        %{}
    end
  end
end
