defmodule Shared.Domain.Events.BaseEvent do
  @moduledoc """
  イベントソーシングのための基本イベント型
  すべてのドメインイベントはこのビヘイビアを実装する
  """

  @doc """
  イベントの一意識別子を返す
  """
  @callback event_id() :: String.t()

  @doc """
  イベントが発生した集約のIDを返す
  """
  @callback aggregate_id() :: String.t()

  @doc """
  イベントタイプを返す
  """
  @callback event_type() :: atom()

  @doc """
  イベントのバージョンを返す
  """
  @callback event_version() :: pos_integer()

  @doc """
  イベントが発生した時刻を返す
  """
  @callback occurred_at() :: DateTime.t()

  @doc """
  イベントのペイロードを返す
  """
  @callback payload() :: map()

  @doc """
  イベントのメタデータを返す
  """
  @callback metadata() :: map()

  @doc """
  イベントを構造体から基本マップに変換する
  """
  @callback to_map(event :: struct()) :: map()

  @doc """
  マップから構造体に変換する
  """
  @callback from_map(data :: map()) :: {:ok, struct()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Events.BaseEvent

      @doc """
      イベントIDを生成する
      """
      @spec generate_event_id() :: String.t()
      def generate_event_id do
        :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
      end

      @doc """
      現在時刻を取得する
      """
      @spec current_timestamp() :: DateTime.t()
      def current_timestamp do
        DateTime.utc_now()
      end

      @impl true
      def event_id, do: __MODULE__.event_id

      @impl true
      def aggregate_id, do: __MODULE__.aggregate_id

      @impl true
      def event_type, do: __MODULE__ |> Module.split() |> List.last() |> String.to_atom()

      @impl true
      def event_version, do: 1

      @impl true
      def occurred_at, do: __MODULE__.occurred_at

      @impl true
      def metadata, do: __MODULE__.metadata || %{}

      @impl true
      def to_map(event) do
        %{
          event_id: event.event_id,
          aggregate_id: event.aggregate_id,
          event_type: event_type(),
          event_version: event_version(),
          occurred_at: event.occurred_at,
          payload: payload_to_map(event),
          metadata: event.metadata
        }
      end

      @impl true
      def from_map(data) do
        with {:ok, payload} <- map_to_payload(data["payload"] || data[:payload]) do
          event = struct(__MODULE__, Map.merge(payload, %{
            event_id: data["event_id"] || data[:event_id],
            aggregate_id: data["aggregate_id"] || data[:aggregate_id],
            occurred_at: parse_timestamp(data["occurred_at"] || data[:occurred_at]),
            metadata: data["metadata"] || data[:metadata] || %{}
          }))
          {:ok, event}
        end
      end

      # オーバーライド可能な関数
      defp payload_to_map(event), do: Map.from_struct(event) |> Map.drop([:event_id, :aggregate_id, :occurred_at, :metadata])
      defp map_to_payload(map), do: {:ok, map}

      defp parse_timestamp(%DateTime{} = dt), do: dt
      defp parse_timestamp(timestamp) when is_binary(timestamp) do
        case DateTime.from_iso8601(timestamp) do
          {:ok, dt, _} -> dt
          _ -> DateTime.utc_now()
        end
      end
      defp parse_timestamp(_), do: DateTime.utc_now()

      defoverridable [payload_to_map: 1, map_to_payload: 1]
    end
  end
end