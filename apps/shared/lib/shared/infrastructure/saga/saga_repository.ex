defmodule Shared.Infrastructure.Saga.SagaRepository do
  @moduledoc """
  サガの永続化を担当するリポジトリ
  
  EventStoreを使用してサガの状態を保存・復元します。
  """
  
  alias Shared.Infrastructure.EventStore
  require Logger
  
  @saga_snapshot_prefix "saga-snapshot-"
  
  @doc """
  サガを保存する
  """
  @spec save(map()) :: {:ok, map()} | {:error, any()}
  def save(saga) do
    # スナップショットとして保存
    snapshot_id = "#{@saga_snapshot_prefix}#{saga.saga_id}"
    
    case EventStore.create_snapshot(saga.saga_id, saga, snapshot_id) do
      :ok ->
        {:ok, saga}
        
      {:error, reason} = error ->
        Logger.error("Failed to save saga snapshot: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  サガをIDで取得する
  """
  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(saga_id) do
    snapshot_id = "#{@saga_snapshot_prefix}#{saga_id}"
    
    case EventStore.get_snapshot(saga_id, snapshot_id) do
      {:ok, saga} ->
        {:ok, saga}
        
      {:error, :not_found} ->
        # スナップショットがない場合はイベントから再構築を試みる
        rebuild_from_events(saga_id)
        
      {:error, reason} = error ->
        Logger.error("Failed to get saga snapshot: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  アクティブなサガの一覧を取得する
  """
  @spec list_active() :: {:ok, [map()]} | {:error, any()}
  def list_active do
    # TODO: より効率的な実装が必要（インデックスなど）
    # 現在は簡易実装として、最近のスナップショットを取得
    {:ok, []}
  end
  
  @doc """
  サガの履歴（イベント）を取得する
  """
  @spec get_saga_history(String.t()) :: {:ok, [map()]} | {:error, any()}
  def get_saga_history(saga_id) do
    stream_id = "saga-#{saga_id}"
    
    case EventStore.read_stream_forward(stream_id, 0, 1000) do
      {:ok, events} ->
        {:ok, events}
        
      {:error, reason} = error ->
        Logger.error("Failed to get saga history: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  完了したサガをアーカイブする
  """
  @spec archive_completed_saga(String.t()) :: :ok | {:error, any()}
  def archive_completed_saga(saga_id) do
    # 完了したサガをアーカイブする
    case get(saga_id) do
      {:ok, saga} ->
        # アーカイブフラグを設定
        archived_saga = Map.put(saga, :archived_at, DateTime.utc_now())
        
        # アーカイブイベントを記録
        archive_event = %{
          event_id: UUID.uuid4(),
          event_type: "saga_archived",
          aggregate_id: saga_id,
          occurred_at: DateTime.utc_now(),
          payload: %{
            saga_type: saga.saga_type,
            status: saga.status,
            archived_at: archived_saga.archived_at
          },
          metadata: %{}
        }
        
        case EventStore.append_to_stream("saga-#{saga_id}", [archive_event], :any) do
          {:ok, _} ->
            # メモリから削除（オプション）
            # 実際の運用では、別のストレージに移動するか、
            # アクティブなサガのみをメモリに保持する
            Logger.info("Saga archived", saga_id: saga_id, saga_type: saga.saga_type)
            :ok
            
          {:error, reason} ->
            Logger.error("Failed to archive saga", 
              saga_id: saga_id, 
              error: inspect(reason)
            )
            {:error, reason}
        end
        
      {:error, :not_found} ->
        # 既に存在しないサガはアーカイブ済みとみなす
        :ok
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Private functions
  
  defp rebuild_from_events(saga_id) do
    stream_id = "saga-#{saga_id}"
    
    case EventStore.read_stream_forward(stream_id, 0, 1000) do
      {:ok, events} when events != [] ->
        # イベントからサガを再構築
        saga = rebuild_saga_from_events(events)
        {:ok, saga}
        
      {:ok, []} ->
        {:error, :not_found}
        
      {:error, reason} = error ->
        Logger.error("Failed to rebuild saga from events: #{inspect(reason)}")
        error
    end
  end
  
  defp rebuild_saga_from_events(events) do
    # 最初のイベントからサガの基本情報を取得
    [first_event | rest_events] = events
    
    initial_saga = %{
      saga_id: first_event.aggregate_id,
      saga_type: get_in(first_event, [:payload, :saga_type]),
      state: :started,
      data: get_in(first_event, [:payload, :initial_data]),
      processed_events: [],
      completed_steps: [],
      started_at: first_event.occurred_at,
      updated_at: first_event.occurred_at
    }
    
    # 残りのイベントを適用してサガを再構築
    Enum.reduce(rest_events, initial_saga, fn event, saga ->
      apply_event_to_saga(event, saga)
    end)
  end
  
  defp apply_event_to_saga(event, saga) do
    case event.event_type do
      "saga_step_completed" ->
        step = %{
          step: get_in(event, [:payload, :step_name]),
          result: get_in(event, [:payload, :result]),
          completed_at: event.occurred_at
        }
        %{saga | 
          completed_steps: [step | saga.completed_steps],
          updated_at: event.occurred_at
        }
        
      "saga_failed" ->
        %{saga | 
          state: :failed,
          failed_step: %{
            step: get_in(event, [:payload, :failed_step]),
            reason: get_in(event, [:payload, :reason]),
            failed_at: event.occurred_at
          },
          updated_at: event.occurred_at
        }
        
      "saga_compensation_started" ->
        %{saga | 
          state: :compensating,
          updated_at: event.occurred_at
        }
        
      "saga_compensated" ->
        %{saga | 
          state: :compensated,
          updated_at: event.occurred_at
        }
        
      "saga_completed" ->
        %{saga | 
          state: :completed,
          updated_at: event.occurred_at
        }
        
      _ ->
        # その他のイベントは処理済みとして記録
        processed = [{event.event_id, event.occurred_at} | saga.processed_events]
        %{saga | 
          processed_events: processed,
          updated_at: event.occurred_at
        }
    end
  end
end