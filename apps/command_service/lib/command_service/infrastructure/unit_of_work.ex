defmodule CommandService.Infrastructure.UnitOfWork do
  @moduledoc """
  Unit of Work パターンの実装

  トランザクション境界を管理し、複数のリポジトリ操作を
  単一のトランザクション内で実行します。
  """

  alias CommandService.Repo
  alias Shared.Infrastructure.EventStore.EventStore

  require Logger

  @doc """
  トランザクション内で処理を実行する

  ## Examples

      UnitOfWork.transaction(fn ->
        with {:ok, aggregate} <- CategoryRepository.get(id),
             {:ok, updated} <- CategoryAggregate.execute(aggregate, command),
             {:ok, _} <- CategoryRepository.save(updated) do
          {:ok, updated}
        end
      end)
  """
  def transaction(fun) when is_function(fun, 0) do
    Repo.transaction(fn ->
      case fun.() do
        {:ok, result} -> result
        {:error, reason} -> Repo.rollback(reason)
        result -> result
      end
    end)
  end

  @doc """
  アグリゲートとイベントを保存するトランザクション

  アグリゲートの状態保存とイベントストアへのイベント保存を
  同一トランザクション内で実行します。
  """
  def transaction_with_events(fun) when is_function(fun, 0) do
    Repo.transaction(fn ->
      # イベントを蓄積するプロセス辞書を初期化
      Process.put(:unit_of_work_events, [])

      case fun.() do
        {:ok, result} ->
          # 蓄積されたイベントを取得
          events = Process.get(:unit_of_work_events, []) |> Enum.reverse()

          # イベントをイベントストアに保存
          case save_events(events) do
            :ok ->
              # プロセス辞書をクリーンアップ
              Process.delete(:unit_of_work_events)
              result

            {:error, reason} ->
              Repo.rollback({:event_store_error, reason})
          end

        {:error, reason} ->
          Process.delete(:unit_of_work_events)
          Repo.rollback(reason)

        result ->
          Process.delete(:unit_of_work_events)
          result
      end
    end)
  end

  @doc """
  現在のトランザクションにイベントを追加する

  この関数は transaction_with_events 内でのみ使用してください。
  """
  def add_event(event) do
    current_events = Process.get(:unit_of_work_events, [])
    Process.put(:unit_of_work_events, [event | current_events])
    :ok
  end

  @doc """
  現在のトランザクションに複数のイベントを追加する
  """
  def add_events(events) when is_list(events) do
    Enum.each(events, &add_event/1)
    :ok
  end

  # Private functions

  defp save_events([]), do: :ok

  defp save_events(events) do
    # グループ化してバッチ保存
    events
    |> Enum.group_by(fn event -> 
      # aggregate_id または id フィールドを取得
      case event do
        %{aggregate_id: id} -> id
        %{id: %{value: id}} -> id
        %{id: id} -> id
      end
    end)
    |> Enum.reduce_while(:ok, fn {aggregate_id, aggregate_events}, :ok ->
      # アグリゲートタイプを最初のイベントから取得
      aggregate_type = get_aggregate_type(hd(aggregate_events))
      # 新規作成の場合は expected_version を 0 に設定
      # TODO: 本来はアグリゲートのバージョンを使用すべきだが、現在は新規作成のみ対応
      expected_version = 0
      case EventStore.append_events(aggregate_id, aggregate_type, aggregate_events, expected_version, %{}) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp get_aggregate_type(event) do
    cond do
      function_exported?(event.__struct__, :aggregate_type, 0) ->
        event.__struct__.aggregate_type()

      Map.has_key?(event, :aggregate_type) ->
        event.aggregate_type

      true ->
        # イベントモジュール名から推測
        event.__struct__
        |> Module.split()
        |> Enum.find(&String.contains?(&1, "Events"))
        |> case do
          "CategoryEvents" -> "category"
          "ProductEvents" -> "product"
          "OrderEvents" -> "order"
          _ -> "unknown"
        end
    end
  end
end
