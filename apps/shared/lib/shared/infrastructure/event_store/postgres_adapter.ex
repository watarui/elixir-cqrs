defmodule Shared.Infrastructure.EventStore.PostgresAdapter do
  @moduledoc """
  PostgreSQL ベースのイベントストアアダプター

  イベントストアのビヘイビアを実装し、
  PostgreSQL データベースにイベントを永続化します
  """

  @behaviour Shared.Infrastructure.EventStore.EventStoreBehaviour

  use GenServer
  require Logger

  @table_name "events"
  @snapshots_table "snapshots"

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # EventStoreBehaviour の実装

  @impl true
  def append_to_stream(stream_name, events, expected_version) do
    GenServer.call(__MODULE__, {:append_to_stream, stream_name, events, expected_version})
  end

  @impl true
  def read_stream_forward(stream_name, from_version \\ 0, count \\ :all) do
    GenServer.call(__MODULE__, {:read_stream_forward, stream_name, from_version, count})
  end

  @impl true
  def read_all_events(from_position \\ 0) do
    GenServer.call(__MODULE__, {:read_all_events, from_position})
  end

  @impl true
  def read_events_by_type(event_type, from_position \\ 0) do
    GenServer.call(__MODULE__, {:read_events_by_type, event_type, from_position})
  end

  @impl true
  def create_snapshot(aggregate_id, snapshot, version) do
    GenServer.call(__MODULE__, {:create_snapshot, aggregate_id, snapshot, version})
  end

  @impl true
  def get_snapshot(aggregate_id) do
    GenServer.call(__MODULE__, {:get_snapshot, aggregate_id})
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    Logger.info("PostgresAdapter init with opts: #{inspect(opts)}")

    # URLが指定されている場合はそちらを優先
    db_config =
      if opts[:url] do
        # URLから基本設定を取得し、database設定で上書き
        base_config = parse_database_url(opts[:url])
        Logger.info("Parsed URL config: #{inspect(base_config |> Keyword.delete(:password))}")

        final_config = Keyword.merge(base_config, Keyword.take(opts, [:database, :pool_size]))
        # databaseが指定されていればそれを使用
        if opts[:database] do
          Keyword.put(final_config, :database, opts[:database])
        else
          final_config
        end
      else
        [
          hostname: opts[:hostname] || System.get_env("EVENT_STORE_HOST", "postgres-event"),
          username: opts[:username] || System.get_env("EVENT_STORE_USER", "postgres"),
          password: opts[:password] || System.get_env("EVENT_STORE_PASSWORD", "postgres"),
          database: opts[:database] || System.get_env("EVENT_STORE_DB", "event_store"),
          port: opts[:port] || System.get_env("EVENT_STORE_PORT", "5432") |> String.to_integer()
        ]
      end

    Logger.info(
      "Connecting to event store with config: #{inspect(Map.new(db_config) |> Map.delete(:password))}"
    )

    case Postgrex.start_link(db_config) do
      {:ok, conn} ->
        Logger.info("Successfully connected to event store")
        create_tables(conn)
        {:ok, %{conn: conn}}

      {:error, reason} ->
        Logger.error("Failed to connect to event store: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:append_to_stream, stream_name, events, expected_version}, _from, state) do
    Logger.info(
      "Appending #{length(events)} events to stream: #{stream_name}, expected version: #{expected_version}"
    )

    result =
      Postgrex.transaction(state.conn, fn conn ->
        # 現在のバージョンを確認
        current_version = get_stream_version(conn, stream_name)
        Logger.debug("Current version for stream #{stream_name}: #{current_version}")

        if expected_version == :any || expected_version == :any_version ||
             current_version == expected_version do
          # イベントを挿入
          version =
            Enum.reduce(events, current_version, fn event, version ->
              new_version = version + 1

              case insert_event(conn, stream_name, event, new_version) do
                {:ok, _} ->
                  Logger.debug("Event inserted: #{event.__struct__} at version #{new_version}")

                {:error, reason} ->
                  Logger.error("Failed to insert event: #{inspect(reason)}")
                  raise "Event insertion failed: #{inspect(reason)}"
              end

              new_version
            end)

          {:ok, version}
        else
          Logger.error("Version mismatch: expected #{expected_version}, got #{current_version}")
          {:error, :version_mismatch}
        end
      end)

    case result do
      {:ok, {:ok, version}} ->
        Logger.info("Successfully appended events, new version: #{version}")
        {:reply, {:ok, version}, state}

      {:ok, error} ->
        Logger.error("Transaction failed: #{inspect(error)}")
        {:reply, error, state}

      {:error, reason} ->
        Logger.error("Database error: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:read_stream_forward, stream_name, from_version, count}, _from, state) do
    limit_clause =
      if count != :all do
        "LIMIT #{count}"
      else
        ""
      end

    query = """
    SELECT event_type, event_data, version, occurred_at
    FROM #{@table_name}
    WHERE stream_name = $1 AND version > $2
    ORDER BY version ASC
    #{limit_clause}
    """

    case Postgrex.query(state.conn, query, [stream_name, from_version]) do
      {:ok, %{rows: rows}} ->
        events = Enum.map(rows, &deserialize_event/1)
        {:reply, {:ok, events}, state}

      {:error, reason} ->
        Logger.error("Failed to read stream: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:read_all_events, from_position}, _from, state) do
    query = """
    SELECT event_type, event_data, version, occurred_at, stream_name
    FROM #{@table_name}
    WHERE position > $1
    ORDER BY position ASC
    LIMIT 1000
    """

    case Postgrex.query(state.conn, query, [from_position]) do
      {:ok, %{rows: rows}} ->
        events = Enum.map(rows, &deserialize_event_with_metadata/1)
        {:reply, {:ok, events}, state}

      {:error, reason} ->
        Logger.error("Failed to read all events: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:read_events_by_type, event_type, from_position}, _from, state) do
    query = """
    SELECT event_type, event_data, version, occurred_at, stream_name
    FROM #{@table_name}
    WHERE event_type = $1 AND position > $2
    ORDER BY position ASC
    """

    type_name = event_type |> to_string() |> String.split(".") |> List.last()

    case Postgrex.query(state.conn, query, [type_name, from_position]) do
      {:ok, %{rows: rows}} ->
        events = Enum.map(rows, &deserialize_event_with_metadata/1)
        {:reply, {:ok, events}, state}

      {:error, reason} ->
        Logger.error("Failed to read events by type: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:create_snapshot, aggregate_id, snapshot, version}, _from, state) do
    query = """
    INSERT INTO #{@snapshots_table} (aggregate_id, snapshot_data, version, created_at)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (aggregate_id) DO UPDATE
    SET snapshot_data = $2, version = $3, created_at = $4
    """

    # snapshotが既にマップの場合はそのまま使用
    snapshot_data =
      if is_map(snapshot) and not is_struct(snapshot) do
        Jason.encode!(snapshot)
      else
        Jason.encode!(Map.from_struct(snapshot))
      end

    case Postgrex.query(state.conn, query, [
           aggregate_id,
           snapshot_data,
           version,
           DateTime.utc_now()
         ]) do
      {:ok, _} -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_snapshot, aggregate_id}, _from, state) do
    query = """
    SELECT snapshot_data, version
    FROM #{@snapshots_table}
    WHERE aggregate_id = $1
    """

    case Postgrex.query(state.conn, query, [aggregate_id]) do
      {:ok, %{rows: [[snapshot_data, version]]}} ->
        snapshot = Jason.decode!(snapshot_data, keys: :atoms)
        {:reply, {:ok, {snapshot, version}}, state}

      {:ok, %{rows: []}} ->
        {:reply, {:error, :not_found}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private functions

  defp create_tables(conn) do
    # イベントテーブルの作成
    events_table = """
    CREATE TABLE IF NOT EXISTS #{@table_name} (
      position BIGSERIAL PRIMARY KEY,
      stream_name VARCHAR(255) NOT NULL,
      version INTEGER NOT NULL,
      event_type VARCHAR(255) NOT NULL,
      event_data JSONB NOT NULL,
      occurred_at TIMESTAMP NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(stream_name, version)
    )
    """

    # インデックスの作成
    indices = [
      "CREATE INDEX IF NOT EXISTS idx_events_stream_name ON #{@table_name} (stream_name)",
      "CREATE INDEX IF NOT EXISTS idx_events_position ON #{@table_name} (position)",
      "CREATE INDEX IF NOT EXISTS idx_events_event_type ON #{@table_name} (event_type)"
    ]

    # スナップショットテーブルの作成
    snapshots_table = """
    CREATE TABLE IF NOT EXISTS #{@snapshots_table} (
      aggregate_id VARCHAR(255) PRIMARY KEY,
      snapshot_data JSONB NOT NULL,
      version INTEGER NOT NULL,
      created_at TIMESTAMP NOT NULL
    )
    """

    # 各SQL文を個別に実行
    with {:ok, _} <- Postgrex.query(conn, events_table, []),
         :ok <-
           Enum.each(indices, fn index_sql ->
             case Postgrex.query(conn, index_sql, []) do
               {:ok, _} -> :ok
               {:error, reason} -> Logger.warning("Index creation warning: #{inspect(reason)}")
             end
           end),
         {:ok, _} <- Postgrex.query(conn, snapshots_table, []) do
      Logger.info("Event store tables created/verified")
    else
      {:error, reason} ->
        Logger.error("Failed to create event store tables: #{inspect(reason)}")
    end
  end

  defp get_stream_version(conn, stream_name) do
    query = """
    SELECT MAX(version) FROM #{@table_name}
    WHERE stream_name = $1
    """

    case Postgrex.query(conn, query, [stream_name]) do
      {:ok, %{rows: [[nil]]}} -> 0
      {:ok, %{rows: [[version]]}} -> version
      _ -> 0
    end
  end

  defp insert_event(conn, stream_name, event, version) do
    query = """
    INSERT INTO #{@table_name} (stream_name, version, event_type, event_data, occurred_at)
    VALUES ($1, $2, $3, $4, $5)
    """

    # Handle both struct events and plain maps
    {event_type, event_data, occurred_at} =
      if is_struct(event) do
        type = event.__struct__ |> Module.split() |> List.last()
        data = Jason.encode!(Map.from_struct(event))
        timestamp = Map.get(event, :occurred_at, DateTime.utc_now())
        {type, data, timestamp}
      else
        # For plain maps, extract event_type from the map
        type = Map.get(event, :event_type, "UnknownEvent")
        timestamp = Map.get(event, :occurred_at, DateTime.utc_now())
        # Remove internal fields before encoding
        data =
          event
          |> Map.drop([:event_type, :occurred_at])
          |> Jason.encode!()

        {type, data, timestamp}
      end

    Logger.debug("Inserting event: type=#{event_type}, stream=#{stream_name}, version=#{version}")

    result =
      Postgrex.query(conn, query, [
        stream_name,
        version,
        event_type,
        event_data,
        occurred_at
      ])

    case result do
      {:ok, _} ->
        Logger.debug("Event successfully inserted")
        {:ok, nil}

      {:error, reason} ->
        Logger.error("Event insertion failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp deserialize_event([event_type, event_data, _version, occurred_at]) do
    module = resolve_event_module(event_type)

    data =
      Jason.decode!(event_data, keys: :atoms)
      |> Map.put(:occurred_at, occurred_at)

    # If module is Map, just return the data as a map
    if module == Map do
      Map.put(data, :event_type, event_type)
    else
      struct(module, data)
    end
  end

  defp deserialize_event_with_metadata([
         event_type,
         event_data,
         _version,
         occurred_at,
         stream_name
       ]) do
    event = deserialize_event([event_type, event_data, nil, occurred_at])

    # stream_nameから aggregate_id を抽出
    aggregate_id =
      case String.split(stream_name, "-", parts: 2) do
        ["aggregate", id] -> id
        _ -> nil
      end

    if aggregate_id && is_map(event) do
      Map.put(event, :aggregate_id, aggregate_id)
    else
      event
    end
  end

  defp resolve_event_module(event_type) do
    case event_type do
      "ProductCreated" ->
        Shared.Domain.Events.ProductEvents.ProductCreated

      "ProductUpdated" ->
        Shared.Domain.Events.ProductEvents.ProductUpdated

      "ProductDeleted" ->
        Shared.Domain.Events.ProductEvents.ProductDeleted

      "ProductPriceChanged" ->
        Shared.Domain.Events.ProductEvents.ProductPriceChanged

      "CategoryCreated" ->
        Shared.Domain.Events.CategoryEvents.CategoryCreated

      "CategoryUpdated" ->
        Shared.Domain.Events.CategoryEvents.CategoryUpdated

      "CategoryDeleted" ->
        Shared.Domain.Events.CategoryEvents.CategoryDeleted

      # Saga events
      "SagaStarted" ->
        Shared.Domain.Saga.SagaEvents.SagaStarted

      "SagaCompleted" ->
        Shared.Domain.Saga.SagaEvents.SagaCompleted

      "SagaFailed" ->
        Shared.Domain.Saga.SagaEvents.SagaFailed

      "SagaCompensated" ->
        Shared.Domain.Saga.SagaEvents.SagaCompensated

      "SagaStepCompleted" ->
        Shared.Domain.Saga.SagaEvents.SagaStepCompleted

      "SagaStepFailed" ->
        Shared.Domain.Saga.SagaEvents.SagaStepFailed

      "SagaCompensationStarted" ->
        Shared.Domain.Saga.SagaEvents.SagaCompensationStarted

      # Other events
      _ ->
        # For unknown event types, return a generic map module
        Logger.warning("Unknown event type: #{event_type}, using Map")
        Map
    end
  end

  # データベースURLをパースする
  defp parse_database_url(url) do
    uri = URI.parse(url)

    [username, password] =
      case uri.userinfo do
        nil -> [nil, nil]
        userinfo -> String.split(userinfo, ":", parts: 2)
      end

    [
      hostname: uri.host || "localhost",
      port: uri.port || 5432,
      database: String.trim_leading(uri.path || "", "/"),
      username: username,
      password: password
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end
end
