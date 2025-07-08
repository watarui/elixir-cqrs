defmodule CommandService.Infrastructure.SagaCommandDispatcher do
  @moduledoc """
  CommandServiceアプリ側のサガコマンドディスパッチャー実装
  SharedアプリのCommandDispatcherBehaviourを実装し、
  CommandBusを使用してコマンドを実行する
  """

  @behaviour Shared.Domain.Saga.CommandDispatcherBehaviour

  require Logger

  alias CommandService.Application.CommandBus
  alias Shared.Infrastructure.EventBus

  @impl true
  def dispatch(command) do
    # SAGAコマンドハンドラーを直接使用
    alias CommandService.Application.Handlers.SagaCommandHandler

    case SagaCommandHandler.handle_command(command) do
      {:ok, result} ->
        Logger.info("Saga command dispatched successfully",
          command_type: Map.get(command, :type),
          saga_id: get_in(command, [:metadata, :saga_id])
        )

        {:ok, result}

      {:error, reason} = error ->
        Logger.error("Failed to dispatch saga command",
          command_type: Map.get(command, :type),
          saga_id: get_in(command, [:metadata, :saga_id]),
          error: inspect(reason)
        )

        error
    end
  end

  @impl true
  def dispatch_parallel(commands) do
    tasks =
      Enum.map(commands, fn command ->
        Task.async(fn -> dispatch(command) end)
      end)

    results = Task.await_many(tasks, 30_000)

    # すべて成功した場合のみ成功とする
    errors =
      Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, result} -> result end)}
    else
      # エラーがリストで返されている場合の処理
      {:error, errors}
    end
  end

  @impl true
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

  # defp enrich_command_with_saga_metadata(command) do
  #   # 既存のmetadataを保持しつつ、saga関連の情報を追加
  #   existing_metadata = Map.get(command, :metadata, %{})
  #
  #   enriched_metadata =
  #     Map.merge(existing_metadata, %{
  #       dispatched_at: DateTime.utc_now(),
  #       dispatcher: "SagaCommandDispatcher"
  #     })
  #
  #   Map.put(command, :metadata, enriched_metadata)
  # end

  # defp publish_command_result_event(command, status, result) do
  #   saga_id = get_in(command, [:metadata, :saga_id])
  #
  #   if saga_id do
  #     event_type =
  #       case status do
  #         :success -> "#{get_command_type(command)}_succeeded"
  #         :failure -> "#{get_command_type(command)}_failed"
  #       end
  #
  #     event = %{
  #       event_id: UUID.uuid4(),
  #       event_type: event_type,
  #       aggregate_id: saga_id,
  #       occurred_at: DateTime.utc_now(),
  #       payload: %{
  #         command: sanitize_command(command),
  #         result: result
  #       },
  #       metadata: %{
  #         saga_id: saga_id
  #       }
  #     }
  #
  #     EventBus.publish(event)
  #   end
  # end

  # defp sanitize_command(command) do
  #   # センシティブな情報を除去
  #   command
  #   |> Map.drop([:password, :credit_card, :secret])
  #   |> Map.update(:metadata, %{}, fn metadata ->
  #     Map.drop(metadata, [:auth_token, :api_key])
  #   end)
  # end
end
