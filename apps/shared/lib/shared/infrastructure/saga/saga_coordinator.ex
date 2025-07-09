defmodule Shared.Infrastructure.Saga.SagaCoordinator do
  @moduledoc """
  サガコーディネーター

  サガの実行を調整し、イベントとコマンドの処理を管理します
  """

  use GenServer

  alias Shared.Infrastructure.EventBus
  alias Shared.Infrastructure.EventStore.EventStore

  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  新しいサガを開始する
  """
  def start_saga(saga_module, initial_data) do
    GenServer.call(__MODULE__, {:start_saga, saga_module, initial_data})
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

    state = %{
      # saga_id => {saga_module, saga_state}
      active_sagas: %{},
      # event_type => [saga_modules]
      saga_mappings: %{
        "order.created" => [CommandService.Domain.Sagas.OrderSaga]
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:start_saga, saga_module, initial_data}, _from, state) do
    saga_id = UUID.uuid4()
    saga_state = saga_module.new(saga_id, initial_data)

    # サガを保存
    new_active_sagas = Map.put(state.active_sagas, saga_id, {saga_module, saga_state})

    # 初期コマンドを発行
    case get_next_commands(saga_module, saga_state) do
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
        case saga_module.handle_event(event, saga_state) do
          {:ok, commands} ->
            # コマンドを発行
            Enum.each(commands, &dispatch_command/1)

            # サガの状態を更新
            updated_saga_state = update_saga_state_from_event(saga_state, event)

            # 完了または失敗したサガをチェック
            if saga_module.completed?(updated_saga_state) or
                 saga_module.failed?(updated_saga_state) do
              # サガを永続化してアクティブリストから削除
              persist_saga(saga_id, saga_module, updated_saga_state)
              %{acc_state | active_sagas: Map.delete(acc_state.active_sagas, saga_id)}
            else
              # サガの状態を更新
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
      end)

    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:event, event_type, event}, state) do
    # コマンドとクエリイベントは無視する
    if event_type in [:commands, :queries] do
      {:noreply, state}
    else
      # EventBus からのイベントを処理
      handle_cast({:handle_event, event}, state)
    end
  end

  # Private functions

  defp get_event_type(event) do
    cond do
      function_exported?(event.__struct__, :event_type, 0) ->
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
      case get_next_commands(saga_module, saga_state) do
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

  defp get_next_commands(saga_module, saga_state) do
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

  defp persist_saga(saga_id, saga_module, saga_state) do
    # サガの最終状態を永続化
    Logger.info("Persisting saga #{saga_id} with state: #{saga_state.state}")
    # TODO: サガリポジトリの実装
  end
end
