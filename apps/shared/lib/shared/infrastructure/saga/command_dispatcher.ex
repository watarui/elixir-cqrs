defmodule Shared.Infrastructure.Saga.CommandDispatcher do
  @moduledoc """
  サガからのコマンドをコマンドバスにディスパッチするアダプター
  """
  
  require Logger
  
  alias CommandService.Application.CommandBus
  alias Shared.Infrastructure.EventBus
  
  @doc """
  コマンドをディスパッチする
  """
  @spec dispatch(map()) :: {:ok, any()} | {:error, any()}
  def dispatch(command) do
    case get_command_type(command) do
      nil ->
        {:error, "Unknown command type"}
        
      command_type ->
        # コマンドにsaga_idを含むmetadataを追加
        enriched_command = enrich_command_with_saga_metadata(command)
        
        # コマンドバスに送信
        case CommandBus.dispatch(enriched_command) do
          {:ok, result} ->
            Logger.info("Saga command dispatched successfully",
              command_type: command_type,
              saga_id: get_in(command, [:metadata, :saga_id])
            )
            
            # 成功イベントを発行（サガが監視できるように）
            publish_command_result_event(enriched_command, :success, result)
            
            {:ok, result}
            
          {:error, reason} = error ->
            Logger.error("Failed to dispatch saga command",
              command_type: command_type,
              saga_id: get_in(command, [:metadata, :saga_id]),
              error: inspect(reason)
            )
            
            # 失敗イベントを発行
            publish_command_result_event(enriched_command, :failure, reason)
            
            error
        end
    end
  end
  
  @doc """
  複数のコマンドを並列でディスパッチする
  """
  @spec dispatch_parallel([map()]) :: {:ok, [any()]} | {:error, any()}
  def dispatch_parallel(commands) do
    tasks = Enum.map(commands, fn command ->
      Task.async(fn -> dispatch(command) end)
    end)
    
    results = Task.await_many(tasks, 30_000)
    
    # すべて成功した場合のみ成功とする
    errors = Enum.filter(results, fn
      {:error, _} -> true
      _ -> false
    end)
    
    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, result} -> result end)}
    else
      {:error, errors}
    end
  end
  
  @doc """
  補償コマンドをディスパッチする
  """
  @spec dispatch_compensation(map()) :: {:ok, any()} | {:error, any()}
  def dispatch_compensation(command) do
    # 補償コマンドは失敗してもサガを停止させない
    enriched_command = Map.put(command, :is_compensation, true)
    
    case dispatch(enriched_command) do
      {:ok, result} ->
        Logger.info("Compensation command executed successfully",
          command_type: get_command_type(command),
          saga_id: get_in(command, [:metadata, :saga_id])
        )
        {:ok, result}
        
      {:error, reason} ->
        Logger.error("Compensation command failed, but continuing",
          command_type: get_command_type(command),
          saga_id: get_in(command, [:metadata, :saga_id]),
          error: inspect(reason)
        )
        # 補償の失敗は成功として扱う（サガを継続させるため）
        {:ok, :compensation_failed}
    end
  end
  
  # Private functions
  
  defp get_command_type(command) do
    case command do
      %{__struct__: module} -> module |> Module.split() |> List.last()
      %{type: type} -> type
      _ -> nil
    end
  end
  
  defp enrich_command_with_saga_metadata(command) do
    # 既存のmetadataを保持しつつ、saga関連の情報を追加
    existing_metadata = Map.get(command, :metadata, %{})
    
    enriched_metadata = Map.merge(existing_metadata, %{
      dispatched_at: DateTime.utc_now(),
      dispatcher: "SagaCommandDispatcher"
    })
    
    Map.put(command, :metadata, enriched_metadata)
  end
  
  defp publish_command_result_event(command, status, result) do
    saga_id = get_in(command, [:metadata, :saga_id])
    
    if saga_id do
      event_type = case status do
        :success -> "#{get_command_type(command)}_succeeded"
        :failure -> "#{get_command_type(command)}_failed"
      end
      
      event = %{
        event_id: UUID.uuid4(),
        event_type: event_type,
        aggregate_id: saga_id,
        occurred_at: DateTime.utc_now(),
        payload: %{
          command: sanitize_command(command),
          result: result
        },
        metadata: %{
          saga_id: saga_id
        }
      }
      
      EventBus.publish(event)
    end
  end
  
  defp sanitize_command(command) do
    # センシティブな情報を除去
    command
    |> Map.drop([:password, :credit_card, :secret])
    |> Map.update(:metadata, %{}, fn metadata ->
      Map.drop(metadata, [:auth_token, :api_key])
    end)
  end
end