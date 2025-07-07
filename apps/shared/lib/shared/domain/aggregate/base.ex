defmodule Shared.Domain.Aggregate.Base do
  @moduledoc """
  イベントソーシング対応のアグリゲート基底モジュール
  """

  @doc """
  アグリゲートIDを返す
  """
  @callback aggregate_id(aggregate :: struct()) :: String.t() | nil

  @doc """
  アグリゲートのバージョンを返す
  """
  @callback version() :: non_neg_integer()

  @doc """
  コマンドを実行してイベントを生成する
  """
  @callback execute(aggregate :: struct(), command :: struct()) :: {:ok, list(struct())} | {:error, term()}

  @doc """
  イベントを適用してアグリゲートの状態を更新する
  """
  @callback apply_event(aggregate :: struct(), event :: struct()) :: struct()

  @doc """
  イベントのリストからアグリゲートを再構築する
  """
  @callback load_from_events(events :: list(struct())) :: struct()

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Aggregate.Base

      @impl true
      def version, do: 0

      @impl true
      def load_from_events(events) do
        Enum.reduce(events, %__MODULE__{version: 0}, fn event, aggregate ->
          aggregate
          |> apply_event(event)
          |> Map.update!(:version, &(&1 + 1))
        end)
      end

      @doc """
      新しいイベントを追加する
      """
      def add_event(%__MODULE__{} = aggregate, event) do
        %{aggregate | pending_events: aggregate.pending_events ++ [event]}
      end

      @doc """
      複数のイベントを追加する
      """
      def add_events(%__MODULE__{} = aggregate, events) do
        %{aggregate | pending_events: aggregate.pending_events ++ events}
      end

      @doc """
      保留中のイベントを取得してクリアする
      """
      def get_pending_events(%__MODULE__{} = aggregate) do
        {aggregate.pending_events, %{aggregate | pending_events: []}}
      end

      @doc """
      イベントを適用して新しい状態を返す
      """
      def apply_events(%__MODULE__{} = aggregate, events) do
        Enum.reduce(events, aggregate, fn event, acc ->
          acc
          |> apply_event(event)
          |> Map.update!(:version, &(&1 + 1))
        end)
      end

      # デフォルト実装（オーバーライド可能）
      @impl true
      def execute(_aggregate, _command) do
        {:error, :not_implemented}
      end

      @impl true
      def apply_event(aggregate, _event) do
        aggregate
      end

      defoverridable [execute: 2, apply_event: 2]
    end
  end
end