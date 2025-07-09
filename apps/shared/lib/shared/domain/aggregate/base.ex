defmodule Shared.Domain.Aggregate.Base do
  @moduledoc """
  アグリゲートの基底モジュール

  Event Sourcing パターンにおけるアグリゲートの共通機能を提供します
  """

  @type aggregate_id :: String.t()
  @type event :: struct()
  @type aggregate :: struct()

  @callback new() :: aggregate()
  @callback apply_event(aggregate(), event()) :: aggregate()

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Aggregate.Base

      @doc """
      イベントのリストからアグリゲートを再構築する
      """
      @spec rebuild_from_events([event()]) :: aggregate()
      def rebuild_from_events(events) do
        Enum.reduce(events, new(), &apply_event(&2, &1))
      end

      @doc """
      アグリゲートのバージョンを取得する
      """
      @spec get_version(aggregate()) :: integer()
      def get_version(aggregate) do
        Map.get(aggregate, :version, 0)
      end

      @doc """
      アグリゲートのバージョンをインクリメントする
      """
      @spec increment_version(aggregate()) :: aggregate()
      def increment_version(aggregate) do
        Map.update!(aggregate, :version, &(&1 + 1))
      end

      @doc """
      アグリゲートに未適用のイベントを追加する
      """
      @spec add_uncommitted_event(aggregate(), event()) :: aggregate()
      def add_uncommitted_event(aggregate, event) do
        uncommitted_events = Map.get(aggregate, :uncommitted_events, [])
        Map.put(aggregate, :uncommitted_events, uncommitted_events ++ [event])
      end

      @doc """
      未適用のイベントを取得してクリアする
      """
      @spec get_and_clear_uncommitted_events(aggregate()) :: {aggregate(), [event()]}
      def get_and_clear_uncommitted_events(aggregate) do
        events = Map.get(aggregate, :uncommitted_events, [])
        cleared_aggregate = Map.put(aggregate, :uncommitted_events, [])
        {cleared_aggregate, events}
      end

      @doc """
      イベントを適用してアグリゲートを更新する（副作用なし）
      """
      @spec apply_and_record_event(aggregate(), event()) :: aggregate()
      def apply_and_record_event(aggregate, event) do
        aggregate
        |> apply_event(event)
        |> increment_version()
        |> add_uncommitted_event(event)
      end

      defoverridable new: 0, apply_event: 2
    end
  end
end
