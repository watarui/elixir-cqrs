defmodule Shared.Infrastructure.EventStore.EventArchiver do
  @moduledoc """
  イベントアーカイブ機能

  古いイベントをアーカイブテーブルに移動し、
  メインのイベントテーブルのパフォーマンスを維持する
  """

  alias Shared.Infrastructure.EventStore.Repo
  alias Shared.Infrastructure.EventStore.Schema.Event
  import Ecto.Query
  require Logger

  # デフォルトのアーカイブ設定
  @default_archive_after_days 90
  @default_batch_size 1000

  @doc """
  指定された日数より古いイベントをアーカイブする
  """
  def archive_old_events(days \\ @default_archive_after_days, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    cutoff_date = calculate_cutoff_date(days)

    Logger.info("Starting event archival for events older than #{cutoff_date}")

    case create_archive_table_if_not_exists() do
      :ok ->
        archive_events_in_batches(cutoff_date, batch_size)

      {:error, reason} ->
        Logger.error("Failed to create archive table: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  アーカイブされたイベントを検索する
  """
  def search_archived_events(aggregate_id, from_date \\ nil, to_date \\ nil) do
    query = """
    SELECT * FROM events_archive
    WHERE aggregate_id = $1
    #{if from_date, do: "AND inserted_at >= $2", else: ""}
    #{if to_date, do: "AND inserted_at <= $#{if from_date, do: "3", else: "2"}", else: ""}
    ORDER BY event_version ASC
    """

    params =
      [aggregate_id] ++
        if(from_date, do: [from_date], else: []) ++
        if to_date, do: [to_date], else: []

    case Repo.query(query, params) do
      {:ok, %{rows: rows, columns: columns}} ->
        events =
          Enum.map(rows, fn row ->
            Enum.zip(columns, row) |> Enum.into(%{})
          end)

        {:ok, events}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  アーカイブ統計を取得する
  """
  def get_archive_stats do
    query = """
    SELECT 
      COUNT(*) as total_events,
      MIN(inserted_at) as oldest_event,
      MAX(inserted_at) as newest_event,
      pg_size_pretty(pg_total_relation_size('events_archive')) as table_size
    FROM events_archive
    """

    case Repo.query(query) do
      {:ok, %{rows: [[total, oldest, newest, size]]}} ->
        {:ok,
         %{
           total_events: total,
           oldest_event: oldest,
           newest_event: newest,
           table_size: size
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  アーカイブテーブルをエクスポートする
  """
  def export_archive(path, format \\ :json) do
    case format do
      :json -> export_as_json(path)
      :csv -> export_as_csv(path)
      _ -> {:error, :unsupported_format}
    end
  end

  # Private functions

  defp calculate_cutoff_date(days) do
    DateTime.utc_now()
    |> DateTime.add(-days * 24 * 60 * 60, :second)
    |> DateTime.truncate(:second)
  end

  defp create_archive_table_if_not_exists do
    query = """
    CREATE TABLE IF NOT EXISTS events_archive (
      LIKE events INCLUDING ALL
    );

    -- アーカイブテーブル用のインデックス
    CREATE INDEX IF NOT EXISTS idx_events_archive_aggregate_id 
      ON events_archive(aggregate_id);
    CREATE INDEX IF NOT EXISTS idx_events_archive_inserted_at 
      ON events_archive(inserted_at);
    CREATE INDEX IF NOT EXISTS idx_events_archive_event_type 
      ON events_archive(event_type);
    """

    case Repo.query(query) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp archive_events_in_batches(cutoff_date, batch_size, archived_count \\ 0) do
    # バッチで古いイベントを取得
    events_to_archive =
      from(e in Event,
        where: e.inserted_at < ^cutoff_date,
        order_by: [asc: e.global_sequence],
        limit: ^batch_size
      )
      |> Repo.all()

    case events_to_archive do
      [] ->
        Logger.info("Event archival completed. Total archived: #{archived_count}")
        {:ok, archived_count}

      events ->
        # トランザクション内でアーカイブと削除を実行
        case archive_batch(events) do
          {:ok, count} ->
            new_total = archived_count + count
            Logger.info("Archived batch of #{count} events. Total: #{new_total}")

            # 次のバッチを処理
            archive_events_in_batches(cutoff_date, batch_size, new_total)

          {:error, reason} ->
            Logger.error("Failed to archive batch: #{inspect(reason)}")
            {:error, {:partial_archive, archived_count, reason}}
        end
    end
  end

  defp archive_batch(events) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:insert_to_archive, fn repo, _changes ->
      # イベントをアーカイブテーブルに挿入
      _event_maps =
        Enum.map(events, fn event ->
          event
          |> Map.from_struct()
          |> Map.drop([:__meta__])
        end)

      query = """
      INSERT INTO events_archive 
      SELECT * FROM events 
      WHERE id = ANY($1::uuid[])
      """

      event_ids = Enum.map(events, & &1.id)

      case repo.query(query, [event_ids]) do
        {:ok, result} -> {:ok, result.num_rows}
        error -> error
      end
    end)
    |> Ecto.Multi.run(:delete_from_events, fn repo, %{insert_to_archive: count} ->
      # 元のテーブルから削除
      event_ids = Enum.map(events, & &1.id)

      query = from(e in Event, where: e.id in ^event_ids)

      case repo.delete_all(query) do
        {deleted_count, _} when deleted_count == count ->
          {:ok, deleted_count}

        {deleted_count, _} ->
          {:error, {:count_mismatch, count, deleted_count}}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delete_from_events: count}} -> {:ok, count}
      {:error, operation, reason, _changes} -> {:error, {operation, reason}}
    end
  end

  defp export_as_json(path) do
    query = "SELECT * FROM events_archive ORDER BY global_sequence"

    case Repo.query(query) do
      {:ok, %{rows: rows, columns: columns}} ->
        events =
          Enum.map(rows, fn row ->
            Enum.zip(columns, row)
            |> Enum.into(%{})
            |> Jason.encode!()
          end)

        content = events |> Enum.join("\n")
        File.write(path, content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp export_as_csv(path) do
    query = "COPY events_archive TO STDOUT WITH CSV HEADER"

    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        File.write(path, Enum.join(rows, "\n"))

      {:error, reason} ->
        {:error, reason}
    end
  end
end
