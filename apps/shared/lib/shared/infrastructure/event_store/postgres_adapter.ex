defmodule Shared.Infrastructure.EventStore.PostgresAdapter do
  @moduledoc """
  PostgreSQL を使用したイベントストアの実装
  """

  @behaviour Shared.Infrastructure.EventStore.EventStore

  import Ecto.Query
  alias Shared.Infrastructure.EventBus
  alias Shared.Infrastructure.EventStore.Schema.Event
  alias Shared.Infrastructure.EventStore.SnapshotStore
  alias Shared.Infrastructure.EventStore.VersionConflictError
  alias Shared.Infrastructure.EventStore.AggregateVersionCache
  require Logger

  @impl true
  def append_events(aggregate_id, aggregate_type, events, expected_version, metadata) do
    Ecto.Multi.new()
    |> validate_version(aggregate_id, expected_version)
    |> insert_events(aggregate_id, aggregate_type, events, expected_version, metadata)
    |> Shared.Infrastructure.EventStore.Repo.transaction()
    |> case do
      {:ok, %{events: inserted_events}} ->
        # イベントバスに発行
        Enum.each(inserted_events, &publish_event/1)
        last_event = List.last(inserted_events)
        # バージョンキャッシュを更新
        AggregateVersionCache.set_version(aggregate_id, last_event.event_version)
        {:ok, last_event.event_version}

      {:error, :validate_version, {:version_mismatch, expected, actual}, _} ->
        {:error,
         %VersionConflictError{
           aggregate_id: aggregate_id,
           expected_version: expected,
           actual_version: actual
         }}

      {:error, _operation, reason, _changes} ->
        Logger.error("Failed to append events: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def get_events(aggregate_id, from_version) do
    query =
      from(e in Event,
        where: e.aggregate_id == ^aggregate_id,
        order_by: [asc: e.event_version]
      )

    query =
      if from_version do
        from(e in query, where: e.event_version > ^from_version)
      else
        query
      end

    events = Shared.Infrastructure.EventStore.Repo.all(query)

    decoded_events =
      Enum.map(events, fn event ->
        decode_event(event)
      end)

    {:ok, decoded_events}
  rescue
    e ->
      Logger.error("Failed to get events: #{inspect(e)}")
      {:error, e}
  end

  @impl true
  def get_events_by_type(event_type, opts) do
    limit = Keyword.get(opts, :limit, 100)
    after_id = Keyword.get(opts, :after_id)

    query =
      from(e in Event,
        where: e.event_type == ^event_type,
        order_by: [asc: e.global_sequence],
        limit: ^limit
      )

    query =
      if after_id do
        from(e in query, where: e.id > ^after_id)
      else
        query
      end

    events = Shared.Infrastructure.EventStore.Repo.all(query)

    decoded_events =
      Enum.map(events, fn event ->
        decode_event(event)
      end)

    {:ok, decoded_events}
  rescue
    e ->
      Logger.error("Failed to get events by type: #{inspect(e)}")
      {:error, e}
  end

  @impl true
  def subscribe(subscriber, opts) do
    event_types = Keyword.get(opts, :event_types, :all)

    if event_types == :all do
      EventBus.subscribe_all()
    else
      Enum.each(event_types, &EventBus.subscribe/1)
    end

    {:ok, {subscriber, event_types}}
  end

  @impl true
  def unsubscribe({_subscriber, event_types}) do
    if event_types == :all do
      EventBus.unsubscribe_all()
    else
      Enum.each(event_types, &EventBus.unsubscribe/1)
    end

    :ok
  end

  @impl true
  def get_events_after(after_id, limit) do
    query =
      from(e in Event,
        where: e.global_sequence > ^after_id,
        order_by: [asc: e.global_sequence]
      )

    query =
      if limit do
        from(e in query, limit: ^limit)
      else
        query
      end

    events = Shared.Infrastructure.EventStore.Repo.all(query)

    decoded_events =
      Enum.map(events, fn event ->
        event
        |> decode_event()
        |> Map.put(:id, event.global_sequence)
      end)

    {:ok, decoded_events}
  rescue
    e ->
      Logger.error("Failed to get events after id #{after_id}: #{inspect(e)}")
      {:error, e}
  end

  # Private functions

  defp validate_version(multi, aggregate_id, expected_version) do
    Ecto.Multi.run(multi, :validate_version, fn repo, _changes ->
      current_version = get_current_version(repo, aggregate_id)

      if current_version == expected_version do
        {:ok, :valid}
      else
        {:error, {:version_mismatch, expected_version, current_version}}
      end
    end)
  end

  defp get_current_version(repo, aggregate_id) do
    # キャッシュからバージョンを取得
    case AggregateVersionCache.get_version(aggregate_id) do
      {:ok, version} ->
        version

      {:error, :not_cached} ->
        # キャッシュにない場合は DB から取得
        query =
          from(e in Event,
            where: e.aggregate_id == ^aggregate_id,
            select: max(e.event_version)
          )

        version = Shared.Infrastructure.EventStore.Repo.one(query) || 0
        # キャッシュに保存
        AggregateVersionCache.set_version(aggregate_id, version)
        version
    end
  end

  defp insert_events(multi, aggregate_id, aggregate_type, events, expected_version, metadata) do
    Ecto.Multi.run(multi, :events, fn repo, _changes ->
      event_records =
        events
        |> Enum.with_index(1)
        |> Enum.map(fn {event, index} ->
          %{
            aggregate_id: aggregate_id,
            aggregate_type: aggregate_type,
            event_type: event.__struct__.event_type(),
            event_data: encode_event_data(event),
            event_version: expected_version + index,
            metadata: metadata,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)

      {count, inserted} = Shared.Infrastructure.EventStore.Repo.insert_all(Event, event_records, returning: true)

      if count == length(events) do
        {:ok, inserted}
      else
        {:error, :insert_failed}
      end
    end)
  end

  defp encode_event_data(event) do
    event
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), encode_value(v)} end)
  end

  defp encode_value(%{__struct__: module} = struct) do
    # 値オブジェクトの場合
    cond do
      function_exported?(module, :value, 0) ->
        # EntityId, CategoryNameなどのvalue関数を持つ値オブジェクト
        Map.get(struct, :value)

      module == DateTime ->
        DateTime.to_iso8601(struct)

      module == Decimal ->
        Decimal.to_string(struct)

      true ->
        # その他の構造体はMapに変換
        struct
        |> Map.from_struct()
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new(fn {k, v} -> {Atom.to_string(k), encode_value(v)} end)
    end
  end

  defp encode_value(value), do: value

  defp decode_event(event_record) do
    # イベントタイプからモジュール名を生成
    module =
      case event_record.event_type do
        "category.created" ->
          Shared.Domain.Events.CategoryEvents.CategoryCreated

        "category.updated" ->
          Shared.Domain.Events.CategoryEvents.CategoryUpdated

        "category.deleted" ->
          Shared.Domain.Events.CategoryEvents.CategoryDeleted

        "product.created" ->
          Shared.Domain.Events.ProductEvents.ProductCreated

        "product.updated" ->
          Shared.Domain.Events.ProductEvents.ProductUpdated

        "product.deleted" ->
          Shared.Domain.Events.ProductEvents.ProductDeleted

        "product.price_changed" ->
          Shared.Domain.Events.ProductEvents.ProductPriceChanged

        "order.created" ->
          Shared.Domain.Events.OrderEvents.OrderCreated

        "order.confirmed" ->
          Shared.Domain.Events.OrderEvents.OrderConfirmed

        "order.cancelled" ->
          Shared.Domain.Events.OrderEvents.OrderCancelled

        "order.item_reserved" ->
          Shared.Domain.Events.OrderEvents.OrderItemReserved

        "order.payment_processed" ->
          Shared.Domain.Events.OrderEvents.OrderPaymentProcessed

        _ ->
          # フォールバック: event_typeをモジュール名として解釈
          String.to_existing_atom("Elixir.#{event_record.event_type}")
      end

    event_data =
      event_record.event_data
      |> decode_event_data()
      |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)

    struct(module, event_data)
  end

  defp decode_event_data(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {k, decode_value(k, v)} end)
  end

  defp decode_value(key, value) when is_map(value) do
    # 値オブジェクトの復元
    cond do
      # IDフィールドの場合（"id"、"xxx_id"、"parent_id"など）
      (key == "id" or key =~ ~r/_id$/) and is_binary(value["value"]) ->
        # EntityId の復元
        %Shared.Domain.ValueObjects.EntityId{value: value["value"]}

      key == "price" or key == "total_amount" or key =~ ~r/price$/ ->
        # Money の復元
        %Shared.Domain.ValueObjects.Money{
          amount: Decimal.new(value["amount"]),
          currency: value["currency"]
        }

      key == "name" and Map.has_key?(value, "value") ->
        # ProductName または CategoryName の復元
        %Shared.Domain.ValueObjects.CategoryName{value: value["value"]}

      true ->
        value
    end
  end

  defp decode_value(_key, value) when is_binary(value) do
    # DateTime の復元を試みる
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> datetime
      _ -> value
    end
  end

  defp decode_value(_key, value), do: value

  defp publish_event(event_record) do
    event = decode_event(event_record)
    EventBus.publish(String.to_atom(event_record.event_type), event)
  end

  @impl true
  def save_snapshot(aggregate_id, aggregate_type, version, data, metadata) do
    SnapshotStore.save_snapshot(aggregate_id, aggregate_type, version, data, metadata)
  end

  @impl true
  def get_snapshot(aggregate_id) do
    SnapshotStore.get_latest_snapshot(aggregate_id)
  end
end
