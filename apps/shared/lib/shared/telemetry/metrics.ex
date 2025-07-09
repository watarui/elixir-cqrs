defmodule Shared.Telemetry.Metrics do
  @moduledoc """
  テレメトリメトリクスの定義
  
  アプリケーションのメトリクスを定義します
  """

  import Telemetry.Metrics

  @doc """
  メトリクスの定義を返す
  """
  def metrics do
    [
      # Phoenix メトリクス
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        tags: [:method, :route]
      ),
      counter("phoenix.endpoint.stop.count",
        tags: [:method, :route, :status]
      ),
      
      # Ecto メトリクス
      summary("ecto.query.total_time",
        unit: {:native, :millisecond},
        tags: [:repo, :source]
      ),
      summary("ecto.query.queue_time",
        unit: {:native, :millisecond},
        tags: [:repo, :source]
      ),
      
      # GraphQL メトリクス
      summary("absinthe.execute.operation.stop.duration",
        unit: {:native, :millisecond},
        tags: [:operation_name]
      ),
      counter("absinthe.execute.operation.stop.count",
        tags: [:operation_name]
      ),
      summary("absinthe.resolve.field.stop.duration",
        unit: {:native, :millisecond},
        tags: [:object_type, :field]
      ),
      
      # CQRS メトリクス
      counter("cqrs.command.stop.count",
        event_name: [:cqrs, :command, :stop],
        tags: [:command_type, :status]
      ),
      summary("cqrs.command.stop.duration",
        event_name: [:cqrs, :command, :stop],
        unit: {:native, :millisecond},
        tags: [:command_type]
      ),
      
      counter("cqrs.query.stop.count",
        event_name: [:cqrs, :query, :stop],
        tags: [:query_type, :status]
      ),
      summary("cqrs.query.stop.duration",
        event_name: [:cqrs, :query, :stop],
        unit: {:native, :millisecond},
        tags: [:query_type]
      ),
      
      # Saga メトリクス
      counter("cqrs.saga.stop.count",
        event_name: [:cqrs, :saga, :stop],
        tags: [:saga_type, :status]
      ),
      summary("cqrs.saga.stop.duration",
        event_name: [:cqrs, :saga, :stop],
        unit: {:native, :millisecond},
        tags: [:saga_type]
      ),
      gauge("cqrs.saga.active",
        event_name: [:cqrs, :saga, :active],
        tags: [:saga_type]
      ),
      
      # Event Store メトリクス
      counter("cqrs.event_store.append.count",
        event_name: [:cqrs, :event_store, :append],
        tags: [:stream_name]
      ),
      summary("cqrs.event_store.append.events",
        event_name: [:cqrs, :event_store, :append],
        measurement: :event_count,
        tags: [:stream_name]
      ),
      counter("cqrs.event_store.read.count",
        event_name: [:cqrs, :event_store, :read],
        tags: [:stream_name]
      ),
      
      # Event Bus メトリクス
      counter("cqrs.event.published.count",
        event_name: [:cqrs, :event, :published],
        tags: [:event_type]
      ),
      
      # VM メトリクス
      last_value("vm.memory.total", unit: {:byte, :megabyte}),
      last_value("vm.memory.processes", unit: {:byte, :megabyte}),
      last_value("vm.memory.system", unit: {:byte, :megabyte}),
      last_value("vm.memory.atom", unit: {:byte, :megabyte}),
      last_value("vm.memory.binary", unit: {:byte, :megabyte}),
      last_value("vm.memory.ets", unit: {:byte, :megabyte}),
      
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.system_counts.process_count"),
      summary("vm.system_counts.port_count")
    ]
  end

  @doc """
  カスタムメトリクスを発行する
  """
  def emit_command_metric(command_type, duration, status) do
    :telemetry.execute(
      [:cqrs, :command, :stop],
      %{duration: duration},
      %{command_type: command_type, status: status}
    )
  end

  def emit_query_metric(query_type, duration, status) do
    :telemetry.execute(
      [:cqrs, :query, :stop],
      %{duration: duration},
      %{query_type: query_type, status: status}
    )
  end

  def emit_saga_metric(saga_type, duration, status) do
    :telemetry.execute(
      [:cqrs, :saga, :stop],
      %{duration: duration},
      %{saga_type: saga_type, status: status}
    )
  end

  def emit_saga_active_metric(saga_type, count) do
    :telemetry.execute(
      [:cqrs, :saga, :active],
      %{value: count},
      %{saga_type: saga_type}
    )
  end

  def emit_event_published_metric(event_type) do
    :telemetry.execute(
      [:cqrs, :event, :published],
      %{count: 1},
      %{event_type: event_type}
    )
  end

  def emit_event_store_append_metric(stream_name, event_count) do
    :telemetry.execute(
      [:cqrs, :event_store, :append],
      %{count: 1, event_count: event_count},
      %{stream_name: stream_name}
    )
  end

  def emit_event_store_read_metric(stream_name) do
    :telemetry.execute(
      [:cqrs, :event_store, :read],
      %{count: 1},
      %{stream_name: stream_name}
    )
  end
end