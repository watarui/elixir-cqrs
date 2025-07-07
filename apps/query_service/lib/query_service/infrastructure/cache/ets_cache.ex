defmodule QueryService.Infrastructure.Cache.EtsCache do
  @moduledoc """
  ETSを使用したインメモリキャッシュ

  高速な読み取りアクセスを提供し、クエリサービスのパフォーマンスを向上させます。
  """

  use GenServer
  require Logger

  @table_name :query_cache
  @default_ttl :timer.minutes(5)
  @cleanup_interval :timer.minutes(1)

  # Client API

  @doc """
  キャッシュサーバーを起動します
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  値をキャッシュに保存します

  ## パラメータ
    - key: キャッシュキー
    - value: 保存する値
    - opts: オプション
      - :ttl - 有効期限（ミリ秒）
  """
  @spec put(term(), term(), keyword()) :: :ok
  def put(key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    expires_at = System.monotonic_time(:millisecond) + ttl

    :ets.insert(@table_name, {key, value, expires_at})
    :ok
  end

  @doc """
  キャッシュから値を取得します
  """
  @spec get(term()) :: {:ok, term()} | :not_found
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expires_at}] ->
        now = System.monotonic_time(:millisecond)

        if now < expires_at do
          {:ok, value}
        else
          # 期限切れのエントリを削除
          :ets.delete(@table_name, key)
          :not_found
        end

      [] ->
        :not_found
    end
  end

  @doc """
  キャッシュから値を削除します
  """
  @spec delete(term()) :: :ok
  def delete(key) do
    :ets.delete(@table_name, key)
    :ok
  end

  @doc """
  パターンに一致するすべてのキーを削除します
  """
  @spec delete_pattern(term()) :: :ok
  def delete_pattern(pattern) do
    match_spec = [{pattern, [], [true]}]
    :ets.select_delete(@table_name, match_spec)
    :ok
  end

  @doc """
  キャッシュをクリアします
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  キャッシュ統計を取得します
  """
  @spec stats() :: map()
  def stats do
    %{
      size: :ets.info(@table_name, :size),
      memory: :ets.info(@table_name, :memory)
    }
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # ETSテーブルを作成
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # 定期的なクリーンアップをスケジュール
    schedule_cleanup()

    Logger.info("ETS cache started with table: #{@table_name}")

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private Functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired_entries do
    now = System.monotonic_time(:millisecond)

    # 期限切れのエントリを検索して削除
    match_spec = [
      {
        {:"$1", :"$2", :"$3"},
        [{:<, :"$3", now}],
        [:"$1"]
      }
    ]

    expired_keys = :ets.select(@table_name, match_spec)

    Enum.each(expired_keys, fn key ->
      :ets.delete(@table_name, key)
    end)

    if length(expired_keys) > 0 do
      Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
    end
  end
end
