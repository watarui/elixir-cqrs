defmodule Shared.Infrastructure.EventStore.EventRegistry do
  @moduledoc """
  イベントレジストリ

  イベントタイプの動的登録とバージョン管理を提供する。
  """

  use GenServer

  require Logger

  @table_name :event_registry
  @persistence_file "priv/event_registry.json"

  # Client API

  @doc """
  EventRegistry を開始する
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  イベントタイプを登録する
  """
  @spec register_event_type(module(), keyword()) :: :ok | {:error, term()}
  def register_event_type(event_module, opts \\ []) do
    GenServer.call(__MODULE__, {:register_event_type, event_module, opts})
  end

  @doc """
  イベントタイプ情報を取得する
  """
  @spec get_event_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_event_info(event_type) do
    case :ets.lookup(@table_name, event_type) do
      [{^event_type, info}] -> {:ok, info}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  イベントモジュールを取得する
  """
  @spec get_event_module(String.t()) :: {:ok, module()} | {:error, :not_found}
  def get_event_module(event_type) do
    case get_event_info(event_type) do
      {:ok, %{module: module}} -> {:ok, module}
      error -> error
    end
  end

  @doc """
  すべての登録済みイベントタイプを取得する
  """
  @spec list_event_types() :: [map()]
  def list_event_types do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {_type, info} -> info end)
    |> Enum.sort_by(& &1.event_type)
  end

  @doc """
  イベントバージョンを検証する
  """
  @spec validate_version(String.t(), integer()) :: :ok | {:error, term()}
  def validate_version(event_type, version) do
    case get_event_info(event_type) do
      {:ok, %{version: registered_version}} ->
        if version <= registered_version do
          :ok
        else
          {:error, {:unsupported_version, version, registered_version}}
        end

      {:error, :not_found} ->
        {:error, {:unregistered_event_type, event_type}}
    end
  end

  @doc """
  イベントのデシリアライズ
  """
  @spec deserialize_event(String.t(), map(), integer()) :: {:ok, struct()} | {:error, term()}
  def deserialize_event(event_type, data, version) do
    with :ok <- validate_version(event_type, version),
         {:ok, module} <- get_event_module(event_type) do
      try do
        # バージョン変換が必要な場合
        converted_data =
          if function_exported?(module, :migrate_from_version, 2) do
            module.migrate_from_version(version, data)
          else
            data
          end

        event = struct(module, atomize_keys(converted_data))
        {:ok, event}
      rescue
        e ->
          Logger.error("Failed to deserialize event: #{inspect(e)}")
          {:error, {:deserialization_failed, e}}
      end
    end
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # ETS テーブルの作成
    :ets.new(@table_name, [:named_table, :public, :set, read_concurrency: true])

    # 永続化されたレジストリの読み込み
    load_persisted_registry()

    # 自動検出と登録
    auto_discover_events()

    {:ok, %{}}
  end

  @impl true
  def handle_call({:register_event_type, event_module, opts}, _from, state) do
    case do_register_event_type(event_module, opts) do
      :ok ->
        persist_registry()
        {:reply, :ok, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  # Private functions

  defp do_register_event_type(event_module, opts) do
    try do
      # イベントタイプとバージョンの取得
      event_type =
        if function_exported?(event_module, :event_type, 0) do
          event_module.event_type()
        else
          Keyword.get(opts, :event_type, module_to_event_type(event_module))
        end

      version =
        if function_exported?(event_module, :version, 0) do
          event_module.version()
        else
          Keyword.get(opts, :version, 1)
        end

      # スキーマ情報の取得
      schema =
        if function_exported?(event_module, :schema, 0) do
          event_module.schema()
        else
          extract_schema_from_struct(event_module)
        end

      info = %{
        event_type: event_type,
        module: event_module,
        version: version,
        schema: schema,
        registered_at: DateTime.utc_now(),
        deprecated: Keyword.get(opts, :deprecated, false),
        metadata: Keyword.get(opts, :metadata, %{})
      }

      # 既存の登録をチェック
      case :ets.lookup(@table_name, event_type) do
        [{^event_type, existing}] ->
          if existing.version < version do
            # 新しいバージョンで更新
            :ets.insert(@table_name, {event_type, info})
            Logger.info("Updated event type #{event_type} to version #{version}")
            :ok
          else
            Logger.debug("Event type #{event_type} already registered with same or newer version")
            :ok
          end

        [] ->
          # 新規登録
          :ets.insert(@table_name, {event_type, info})
          Logger.info("Registered event type #{event_type} version #{version}")
          :ok
      end
    rescue
      e ->
        Logger.error("Failed to register event type: #{inspect(e)}")
        {:error, e}
    end
  end

  defp auto_discover_events do
    # イベントモジュールの自動検出
    event_modules = [
      # Order events
      Shared.Domain.Events.OrderEvents.OrderCreated,
      Shared.Domain.Events.OrderEvents.OrderConfirmed,
      Shared.Domain.Events.OrderEvents.OrderCancelled,
      Shared.Domain.Events.OrderEvents.OrderItemReserved,
      Shared.Domain.Events.OrderEvents.OrderPaymentProcessed,

      # Product events
      Shared.Domain.Events.ProductEvents.ProductCreated,
      Shared.Domain.Events.ProductEvents.ProductUpdated,
      Shared.Domain.Events.ProductEvents.ProductDeleted,
      Shared.Domain.Events.ProductEvents.ProductPriceChanged,

      # Category events
      Shared.Domain.Events.CategoryEvents.CategoryCreated,
      Shared.Domain.Events.CategoryEvents.CategoryUpdated,
      Shared.Domain.Events.CategoryEvents.CategoryDeleted
    ]

    Enum.each(event_modules, fn module ->
      if Code.ensure_loaded?(module) do
        do_register_event_type(module, [])
      end
    end)
  end

  defp module_to_event_type(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp extract_schema_from_struct(module) do
    if function_exported?(module, :__struct__, 0) do
      struct = module.__struct__()

      struct
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.reduce(%{}, fn key, acc ->
        Map.put(acc, key, %{type: :any, required: key in module.__info__(:struct)})
      end)
    else
      %{}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  defp persist_registry do
    try do
      data = list_event_types()
      json_data = Jason.encode!(data, pretty: true)

      # ディレクトリの作成
      File.mkdir_p!(Path.dirname(@persistence_file))

      # ファイルへの書き込み
      File.write!(@persistence_file, json_data)
    rescue
      e ->
        Logger.error("Failed to persist event registry: #{inspect(e)}")
    end
  end

  defp load_persisted_registry do
    if File.exists?(@persistence_file) do
      try do
        @persistence_file
        |> File.read!()
        |> Jason.decode!()
        |> Enum.each(fn event_info ->
          # モジュールが存在する場合のみ登録
          module_name = event_info["module"]
          module = String.to_existing_atom(module_name)

          if Code.ensure_loaded?(module) do
            do_register_event_type(module, metadata: event_info["metadata"] || %{})
          end
        end)
      rescue
        e ->
          Logger.warning("Failed to load persisted event registry: #{inspect(e)}")
      end
    end
  end
end
