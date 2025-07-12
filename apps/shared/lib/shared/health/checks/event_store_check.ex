defmodule Shared.Health.Checks.EventStoreCheck do
  @moduledoc """
  イベントストアのヘルスチェック

  イベントストアの動作状態と接続性を確認します。
  """

  alias Shared.Infrastructure.EventStore.EventStore

  require Logger

  @timeout 5_000

  @doc """
  イベントストアの状態を確認
  """
  def check do
    checks = %{
      connection: check_connection(),
      write_capability: check_write_capability(),
      read_capability: check_read_capability(),
      stream_count: get_stream_count()
    }

    failures =
      checks
      |> Enum.filter(fn
        {_, :ok} -> false
        {_, {:ok, _}} -> false
        _ -> true
      end)
      |> Enum.map(fn {check, _} -> check end)

    if Enum.empty?(failures) do
      {:ok, checks}
    else
      {:error, "Event store checks failed: #{inspect(failures)}", checks}
    end
  end

  defp check_connection do
    try do
      # イベントストアプロセスの存在確認
      case Process.whereis(EventStore) do
        nil -> :not_started
        _pid -> :ok
      end
    rescue
      _ -> :error
    end
  end

  defp check_write_capability do
    # ヘルスチェック用の特別なストリームに書き込みテスト
    stream_id = "health_check_#{node()}_#{System.system_time(:millisecond)}"

    event = %{
      aggregate_id: stream_id,
      type: "HealthCheckEvent",
      data: %{timestamp: DateTime.utc_now(), node: node()},
      metadata: %{source: "health_check"},
      occurred_at: DateTime.utc_now()
    }

    task =
      Task.async(fn ->
        # イベントストアのAPIに合わせて調整
        EventStore.store_event(stream_id, event.type, event.data, event.metadata)
      end)

    case Task.yield(task, @timeout) || Task.shutdown(task) do
      {:ok, {:ok, _}} -> :ok
      {:ok, {:error, reason}} -> {:error, reason}
      nil -> :timeout
      {:exit, reason} -> {:error, reason}
    end
  rescue
    e ->
      Logger.error("Event store write check failed: #{inspect(e)}")
      :error
  end

  defp check_read_capability do
    # 最新のイベントを読み込みテスト
    task =
      Task.async(fn ->
        # 最新のイベントを1件取得
        case Shared.Infrastructure.EventStore.Repo.query(
               "SELECT * FROM events ORDER BY id DESC LIMIT 1",
               []
             ) do
          {:ok, %{rows: rows}} when length(rows) > 0 -> {:ok, rows}
          {:ok, %{rows: []}} -> {:ok, []}
          error -> error
        end
      end)

    case Task.yield(task, @timeout) || Task.shutdown(task) do
      {:ok, {:ok, _}} -> :ok
      {:ok, {:error, reason}} -> {:error, reason}
      nil -> :timeout
      {:exit, reason} -> {:error, reason}
    end
  rescue
    e ->
      Logger.error("Event store read check failed: #{inspect(e)}")
      :error
  end

  defp get_stream_count do
    try do
      # ストリーム数の取得（パフォーマンス指標として）
      case Shared.Infrastructure.EventStore.Repo.query(
             "SELECT COUNT(DISTINCT stream_id) FROM events",
             []
           ) do
        {:ok, %{rows: [[count]]}} -> {:ok, count}
        _ -> :error
      end
    rescue
      _ -> :error
    end
  end
end
