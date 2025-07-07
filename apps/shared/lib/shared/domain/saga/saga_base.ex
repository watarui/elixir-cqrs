defmodule Shared.Domain.Saga.SagaBase do
  @moduledoc """
  サガの基底モジュール

  サガは長時間実行されるトランザクションを管理し、
  複数のサービスにまたがる処理を調整します。
  """

  @type saga_id :: String.t()
  @type saga_state :: :started | :processing | :compensating | :completed | :failed | :compensated

  @callback handle_event(event :: map(), state :: map()) ::
              {:ok, commands :: [map()]} | {:error, reason :: any()}
  @callback get_compensation_commands(state :: map()) :: [map()]
  @callback completed?(state :: map()) :: boolean()
  @callback failed?(state :: map()) :: boolean()

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Saga.SagaBase

      require Logger

      @doc """
      サガを開始する
      """
      def start(saga_id, initial_data) do
        %{
          saga_id: saga_id,
          saga_type: __MODULE__ |> Module.split() |> List.last(),
          state: :started,
          data: initial_data,
          processed_events: [],
          pending_commands: [],
          completed_steps: [],
          failed_step: nil,
          started_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end

      @doc """
      サガの状態を更新する
      """
      def update_state(saga, updates) do
        Map.merge(saga, Map.put(updates, :updated_at, DateTime.utc_now()))
      end

      @doc """
      イベントを処理済みとして記録する
      """
      def mark_event_processed(saga, event) do
        processed_events = [{event.event_id, DateTime.utc_now()} | saga.processed_events]
        update_state(saga, %{processed_events: processed_events})
      end

      @doc """
      ステップを完了済みとして記録する
      """
      def mark_step_completed(saga, step_name, result) do
        completed_step = %{
          step: step_name,
          result: result,
          completed_at: DateTime.utc_now()
        }

        completed_steps = [completed_step | saga.completed_steps]
        update_state(saga, %{completed_steps: completed_steps})
      end

      @doc """
      サガを失敗状態にする
      """
      def mark_failed(saga, step_name, reason) do
        update_state(saga, %{
          state: :failed,
          failed_step: %{
            step: step_name,
            reason: reason,
            failed_at: DateTime.utc_now()
          }
        })
      end

      @doc """
      補償処理を開始する
      """
      def start_compensation(saga) do
        update_state(saga, %{state: :compensating})
      end

      @doc """
      補償処理を完了する
      """
      def mark_compensated(saga) do
        update_state(saga, %{state: :compensated})
      end

      @doc """
      サガを完了する
      """
      def mark_completed(saga) do
        update_state(saga, %{state: :completed})
      end

      @doc """
      タイムアウトをチェックする
      """
      def timed_out?(saga, timeout_ms) do
        elapsed = DateTime.diff(DateTime.utc_now(), saga.started_at, :millisecond)
        elapsed > timeout_ms
      end

      defoverridable start: 2
    end
  end
end
