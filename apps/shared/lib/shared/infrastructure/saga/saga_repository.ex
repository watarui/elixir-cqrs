defmodule Shared.Infrastructure.Saga.SagaRepository do
  @moduledoc """
  サガリポジトリ
  
  サガの永続化と読み込みを管理します
  """

  use GenServer

  alias Shared.Infrastructure.EventStore.EventStore
  alias Shared.Domain.Saga.SagaEvents

  require Logger

  @table_name :saga_store

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  サガを保存する
  """
  @spec save(String.t(), module(), map()) :: :ok | {:error, String.t()}
  def save(saga_id, saga_module, saga_state) do
    GenServer.call(__MODULE__, {:save, saga_id, saga_module, saga_state})
  end

  @doc """
  サガを読み込む
  """
  @spec load(String.t()) :: {:ok, {module(), map()}} | {:error, :not_found}
  def load(saga_id) do
    GenServer.call(__MODULE__, {:load, saga_id})
  end

  @doc """
  アクティブなサガを全て取得する
  """
  @spec get_active_sagas() :: [{String.t(), module(), map()}]
  def get_active_sagas do
    GenServer.call(__MODULE__, :get_active_sagas)
  end

  @doc """
  サガを削除する
  """
  @spec delete(String.t()) :: :ok
  def delete(saga_id) do
    GenServer.call(__MODULE__, {:delete, saga_id})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # ETS テーブルを作成
    table = :ets.new(@table_name, [:set, :private])
    
    state = %{
      table: table,
      event_store: Application.get_env(:shared, :event_store_adapter, Shared.Infrastructure.EventStore.InMemoryAdapter)
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:save, saga_id, saga_module, saga_state}, _from, state) do
    # サガの状態を保存
    saga_data = %{
      saga_id: saga_id,
      saga_module: saga_module,
      saga_state: saga_state,
      saved_at: DateTime.utc_now()
    }
    
    :ets.insert(state.table, {saga_id, saga_data})
    
    # イベントとして記録
    event = create_saga_event(saga_state)
    case EventStore.append_events(saga_id, [event], 0, state.event_store) do
      {:ok, _} ->
        Logger.info("Saga saved: #{saga_id}")
        {:reply, :ok, state}
      {:error, reason} ->
        Logger.error("Failed to save saga event: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:load, saga_id}, _from, state) do
    case :ets.lookup(state.table, saga_id) do
      [{^saga_id, saga_data}] ->
        {:reply, {:ok, {saga_data.saga_module, saga_data.saga_state}}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:get_active_sagas, _from, state) do
    active_sagas = :ets.tab2list(state.table)
    |> Enum.filter(fn {_, saga_data} ->
      saga_state = saga_data.saga_state
      saga_state[:state] not in [:completed, :compensated, :failed]
    end)
    |> Enum.map(fn {saga_id, saga_data} ->
      {saga_id, saga_data.saga_module, saga_data.saga_state}
    end)
    
    {:reply, active_sagas, state}
  end

  @impl true
  def handle_call({:delete, saga_id}, _from, state) do
    :ets.delete(state.table, saga_id)
    {:reply, :ok, state}
  end

  # Private functions

  defp create_saga_event(saga_state) do
    event_type = case saga_state[:state] do
      :started -> SagaEvents.SagaStarted
      :processing -> SagaEvents.SagaStepCompleted
      :failed -> SagaEvents.SagaFailed
      :compensating -> SagaEvents.SagaCompensationStarted
      :compensated -> SagaEvents.SagaCompensated
      :completed -> SagaEvents.SagaCompleted
      _ -> SagaEvents.SagaUpdated
    end
    
    event_type.new(%{
      saga_id: saga_state[:saga_id],
      saga_type: saga_state[:saga_type] || "OrderSaga",
      current_step: saga_state[:current_step],
      state: saga_state[:state],
      metadata: %{
        order_id: saga_state[:order_id],
        user_id: saga_state[:user_id],
        completed_steps: saga_state[:completed_steps] || []
      },
      occurred_at: DateTime.utc_now()
    })
  end
end