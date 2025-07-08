defmodule Shared.Infrastructure.EventStore do
  @moduledoc """
  イベントストアの実装
  イベントの永続化と取得を担当する
  """

  @behaviour Shared.Infrastructure.EventStore.EventStoreBehaviour

  alias Shared.Infrastructure.EventStore.PostgresAdapter

  @type aggregate_id :: String.t()
  @type event :: struct()
  @type stream_name :: String.t()
  @type version :: non_neg_integer()
  @type error :: {:error, term()}

  @doc """
  イベントをストリームに追加する
  """
  @spec append_to_stream(stream_name(), list(event()), version()) :: {:ok, version()} | error()
  def append_to_stream(stream_name, events, expected_version) do
    adapter().append_to_stream(stream_name, events, expected_version)
  end

  @doc """
  ストリームからイベントを読み取る
  """
  @spec read_stream_forward(stream_name(), version(), non_neg_integer() | :all) ::
          {:ok, list(event())} | error()
  def read_stream_forward(stream_name, from_version \\ 0, count \\ :all) do
    adapter().read_stream_forward(stream_name, from_version, count)
  end

  @doc """
  特定の集約のイベントを読み取る
  """
  @spec read_aggregate_events(aggregate_id()) :: {:ok, list(event())} | error()
  def read_aggregate_events(aggregate_id) do
    stream_name = aggregate_stream_name(aggregate_id)
    read_stream_forward(stream_name)
  end

  @doc """
  集約のイベントを保存する
  """
  @spec save_aggregate_events(aggregate_id(), list(event()), version()) ::
          {:ok, version()} | error()
  def save_aggregate_events(aggregate_id, events, expected_version) do
    stream_name = aggregate_stream_name(aggregate_id)
    append_to_stream(stream_name, events, expected_version)
  end

  @doc """
  すべてのイベントを読み取る（投影用）
  """
  @spec read_all_events(non_neg_integer()) :: {:ok, list(event())} | error()
  def read_all_events(from_position \\ 0) do
    adapter().read_all_events(from_position)
  end

  @doc """
  特定のイベントタイプのイベントを読み取る
  """
  @spec read_events_by_type(atom(), non_neg_integer()) :: {:ok, list(event())} | error()
  def read_events_by_type(event_type, from_position \\ 0) do
    adapter().read_events_by_type(event_type, from_position)
  end

  @doc """
  集約IDからイベントを取得する

  オプション:
    - after_version: 指定したバージョン以降のイベントのみ取得
  """
  @spec get_events(aggregate_id(), keyword()) :: list(event())
  def get_events(aggregate_id, opts \\ []) do
    stream_name = aggregate_stream_name(aggregate_id)

    from_version =
      case Keyword.get(opts, :after_version) do
        nil -> 0
        version -> version + 1
      end

    case read_stream_forward(stream_name, from_version) do
      {:ok, events} -> events
      {:error, _} -> []
    end
  end

  @doc """
  イベントストアのスナップショットを作成する
  """
  @spec create_snapshot(aggregate_id(), struct(), version()) :: :ok | error()
  def create_snapshot(aggregate_id, snapshot, version) do
    adapter().create_snapshot(aggregate_id, snapshot, version)
  end

  @doc """
  スナップショットを取得する
  """
  @spec get_snapshot(aggregate_id()) ::
          {:ok, {struct(), version()}} | {:error, :not_found} | error()
  def get_snapshot(aggregate_id) do
    adapter().get_snapshot(aggregate_id)
  end

  @doc """
  スナップショットを保存する
  """
  @spec save_snapshot(map()) :: {:ok, term()} | error()
  def save_snapshot(snapshot) do
    case create_snapshot(snapshot.aggregate_id, snapshot, snapshot.version) do
      :ok -> {:ok, snapshot}
      error -> error
    end
  end

  @doc """
  最新のスナップショットを取得する
  """
  @spec get_latest_snapshot(aggregate_id()) :: map() | nil
  def get_latest_snapshot(aggregate_id) do
    # アダプタの実装を直接呼び出す
    case adapter().get_snapshot(aggregate_id) do
      {:ok, {snapshot, _version}} -> snapshot
      {:ok, snapshot} -> snapshot
      {:error, _} -> nil
      nil -> nil
    end
  end

  @doc """
  特定の時間以降のイベントを取得する
  """
  @spec get_events_since(DateTime.t()) :: list(event())
  def get_events_since(since_time) do
    # 全イベントを取得してフィルタリング（簡易実装）
    case adapter().read_all_events(0) do
      {:ok, events} ->
        events
        |> Enum.filter(fn event ->
          case Map.get(event, :created_at) || Map.get(event, :occurred_at) do
            nil ->
              false

            %NaiveDateTime{} = event_time ->
              DateTime.compare(
                DateTime.from_naive!(event_time, "Etc/UTC"),
                since_time
              ) == :gt

            %DateTime{} = event_time ->
              DateTime.compare(event_time, since_time) == :gt

            event_time when is_binary(event_time) ->
              # ISO8601形式の文字列をDateTimeに変換
              case DateTime.from_iso8601(event_time) do
                {:ok, dt, _} -> DateTime.compare(dt, since_time) == :gt
                _ -> false
              end
          end
        end)

      _ ->
        []
    end
  end

  # プライベート関数

  defp aggregate_stream_name(aggregate_id) do
    "aggregate-#{aggregate_id}"
  end

  @doc """
  すべてのイベントを取得する
  """
  @spec get_all_events() :: list(event())
  def get_all_events do
    case adapter().read_all_events(0) do
      {:ok, events} -> events
      _ -> []
    end
  end

  defp adapter do
    # 実行時に設定を取得
    Application.get_env(:shared, :event_store_adapter, PostgresAdapter)
  end
end

defmodule Shared.Infrastructure.EventStore.EventStoreBehaviour do
  @moduledoc """
  イベントストアのビヘイビア定義
  """

  @callback append_to_stream(
              stream_name :: String.t(),
              events :: list(struct()),
              expected_version :: non_neg_integer()
            ) ::
              {:ok, non_neg_integer()} | {:error, term()}

  @callback read_stream_forward(
              stream_name :: String.t(),
              from_version :: non_neg_integer(),
              count :: non_neg_integer() | :all
            ) ::
              {:ok, list(struct())} | {:error, term()}

  @callback read_all_events(from_position :: non_neg_integer()) ::
              {:ok, list(struct())} | {:error, term()}

  @callback read_events_by_type(event_type :: atom(), from_position :: non_neg_integer()) ::
              {:ok, list(struct())} | {:error, term()}

  @callback create_snapshot(
              aggregate_id :: String.t(),
              snapshot :: struct(),
              version :: non_neg_integer()
            ) ::
              :ok | {:error, term()}

  @callback get_snapshot(aggregate_id :: String.t()) ::
              {:ok, {struct(), non_neg_integer()}} | {:error, :not_found} | {:error, term()}
end
