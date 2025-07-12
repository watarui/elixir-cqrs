defmodule Shared.Telemetry.Metrics.PrometheusExporter do
  @moduledoc """
  Prometheus 形式でメトリクスをエクスポート

  Telemetry メトリクスを Prometheus が理解できる形式に変換します。
  """

  use GenServer

  require Logger

  @registry_name :prometheus_registry

  # メトリクス定義
  @metrics [
    # HTTP メトリクス
    {:counter, "http_requests_total", "Total number of HTTP requests", [:method, :status, :path]},
    {:histogram, "http_request_duration_seconds", "HTTP request latency", [:method, :path],
     buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]},

    # コマンドメトリクス
    {:counter, "commands_total", "Total number of commands processed", [:command_type, :status]},
    {:histogram, "command_duration_seconds", "Command execution time", [:command_type],
     buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5]},

    # イベントメトリクス
    {:counter, "events_published_total", "Total number of events published", [:event_type]},
    {:counter, "events_processed_total", "Total number of events processed",
     [:event_type, :handler, :status]},

    # Saga メトリクス
    {:counter, "saga_started_total", "Total number of sagas started", [:saga_type]},
    {:counter, "saga_completed_total", "Total number of sagas completed", [:saga_type, :status]},
    {:histogram, "saga_duration_seconds", "Saga execution time", [:saga_type],
     buckets: [0.1, 0.5, 1, 5, 10, 30, 60, 120]},
    {:counter, "saga_steps_total", "Total number of saga steps executed",
     [:saga_type, :step_name, :status]},
    {:histogram, "saga_step_duration_seconds", "Saga step execution time",
     [:saga_type, :step_name], buckets: [0.01, 0.05, 0.1, 0.5, 1, 5]},

    # データベースメトリクス
    {:counter, "database_queries_total", "Total number of database queries", [:repo, :operation]},
    {:histogram, "database_query_duration_seconds", "Database query execution time",
     [:repo, :operation], buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1]},

    # イベントストアメトリクス
    {:counter, "event_store_operations_total", "Total number of event store operations",
     [:operation, :status]},
    {:gauge, "event_store_stream_length", "Current length of event streams", [:aggregate_type]},

    # サーキットブレーカーメトリクス
    {:counter, "circuit_breaker_state_changes_total", "Total circuit breaker state changes",
     [:service, :from_state, :to_state]},
    {:gauge, "circuit_breaker_state",
     "Current circuit breaker state (0=closed, 1=open, 2=half_open)", [:service]},

    # デッドレターキューメトリクス
    {:counter, "dead_letter_queue_messages_total", "Total messages sent to DLQ",
     [:queue, :reason]},
    {:gauge, "dead_letter_queue_size", "Current size of dead letter queue", [:queue]},

    # システムメトリクス
    {:gauge, "erlang_vm_memory_bytes", "Erlang VM memory usage", [:type]},
    {:gauge, "erlang_vm_process_count", "Number of Erlang processes", []},
    {:gauge, "erlang_vm_port_count", "Number of Erlang ports", []},
    {:counter, "erlang_vm_gc_runs_total", "Total number of garbage collection runs", [:type]}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  メトリクスを Prometheus 形式で取得
  """
  def export do
    GenServer.call(__MODULE__, :export)
  end

  @doc """
  特定のメトリクスを記録
  """
  def record(metric_name, value, labels \\ %{}) do
    GenServer.cast(__MODULE__, {:record, metric_name, value, labels})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # レジストリを初期化
    Registry.start_link(keys: :unique, name: @registry_name)

    # Telemetry ハンドラーをアタッチ
    attach_handlers()

    # システムメトリクスの定期収集を開始
    schedule_system_metrics()

    {:ok, %{metrics: %{}}}
  end

  @impl true
  def handle_call(:export, _from, state) do
    output = build_prometheus_output(state.metrics)
    {:reply, output, state}
  end

  @impl true
  def handle_cast({:record, metric_name, value, labels}, state) do
    updated_metrics = update_metric(state.metrics, metric_name, value, labels)
    {:noreply, %{state | metrics: updated_metrics}}
  end

  @impl true
  def handle_info(:collect_system_metrics, state) do
    # メモリ使用量
    memory_info = :erlang.memory()

    Enum.each(memory_info, fn {type, bytes} ->
      record("erlang_vm_memory_bytes", bytes, %{type: to_string(type)})
    end)

    # プロセス数
    record("erlang_vm_process_count", :erlang.system_info(:process_count))

    # ポート数
    record("erlang_vm_port_count", :erlang.system_info(:port_count))

    # 次回の収集をスケジュール
    schedule_system_metrics()

    {:noreply, state}
  end

  # Private functions

  defp attach_handlers do
    # HTTP メトリクス
    :telemetry.attach_many(
      "prometheus-http",
      [
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :stop]
      ],
      &handle_http_metrics/4,
      nil
    )

    # CQRS メトリクス
    :telemetry.attach_many(
      "prometheus-cqrs",
      [
        [:cqrs, :command, :stop],
        [:cqrs, :event, :published],
        [:cqrs, :event, :processed]
      ],
      &handle_cqrs_metrics/4,
      nil
    )

    # Saga メトリクス
    :telemetry.attach_many(
      "prometheus-saga",
      [
        [:saga, :started],
        [:saga, :completed],
        [:saga, :failed],
        [:saga, :step_completed],
        [:saga, :step_failed]
      ],
      &handle_saga_metrics/4,
      nil
    )

    # データベースメトリクス
    :telemetry.attach(
      "prometheus-ecto",
      [:ecto, :query],
      &handle_ecto_metrics/4,
      nil
    )

    # イベントストアメトリクス
    :telemetry.attach_many(
      "prometheus-event-store",
      [
        [:event_store, :append],
        [:event_store, :read]
      ],
      &handle_event_store_metrics/4,
      nil
    )
  end

  defp handle_http_metrics(_event_name, measurements, metadata, _config) do
    method = metadata.conn.method
    path = normalize_path(metadata.conn.request_path)
    status = metadata.conn.status

    # リクエストカウント
    record("http_requests_total", 1, %{
      method: method,
      status: to_string(status),
      path: path
    })

    # レイテンシ
    if duration = measurements[:duration] do
      duration_seconds = System.convert_time_unit(duration, :native, :microsecond) / 1_000_000

      record("http_request_duration_seconds", duration_seconds, %{
        method: method,
        path: path
      })
    end
  end

  defp handle_cqrs_metrics([:cqrs, :command, :stop], measurements, metadata, _config) do
    command_type = metadata[:command_type] || "unknown"
    status = if metadata[:error], do: "error", else: "success"

    record("commands_total", 1, %{
      command_type: command_type,
      status: status
    })

    if duration = measurements[:duration] do
      duration_seconds = System.convert_time_unit(duration, :native, :microsecond) / 1_000_000

      record("command_duration_seconds", duration_seconds, %{
        command_type: command_type
      })
    end
  end

  defp handle_cqrs_metrics([:cqrs, :event, :published], _measurements, metadata, _config) do
    event_type = metadata[:event_type] || "unknown"
    record("events_published_total", 1, %{event_type: event_type})
  end

  defp handle_cqrs_metrics([:cqrs, :event, :processed], _measurements, metadata, _config) do
    event_type = metadata[:event_type] || "unknown"
    handler = metadata[:handler] || "unknown"
    status = if metadata[:error], do: "error", else: "success"

    record("events_processed_total", 1, %{
      event_type: event_type,
      handler: handler,
      status: status
    })
  end

  defp handle_saga_metrics([:saga, :started], _measurements, metadata, _config) do
    saga_type = metadata[:saga_type] || "unknown"
    record("saga_started_total", 1, %{saga_type: saga_type})
  end

  defp handle_saga_metrics([:saga, status], measurements, metadata, _config)
       when status in [:completed, :failed] do
    saga_type = metadata[:saga_type] || "unknown"

    record("saga_completed_total", 1, %{
      saga_type: saga_type,
      status: to_string(status)
    })

    if duration = measurements[:duration] do
      duration_seconds = System.convert_time_unit(duration, :native, :microsecond) / 1_000_000

      record("saga_duration_seconds", duration_seconds, %{
        saga_type: saga_type
      })
    end
  end

  defp handle_saga_metrics([:saga, step_status], measurements, metadata, _config)
       when step_status in [:step_completed, :step_failed] do
    saga_type = metadata[:saga_type] || "unknown"
    step_name = metadata[:step_name] || "unknown"
    status = if step_status == :step_completed, do: "success", else: "error"

    record("saga_steps_total", 1, %{
      saga_type: saga_type,
      step_name: step_name,
      status: status
    })

    if duration = measurements[:duration] do
      duration_seconds = System.convert_time_unit(duration, :native, :microsecond) / 1_000_000

      record("saga_step_duration_seconds", duration_seconds, %{
        saga_type: saga_type,
        step_name: step_name
      })
    end
  end

  defp handle_ecto_metrics([:ecto, :query], measurements, metadata, _config) do
    repo = metadata.repo |> Module.split() |> List.last()
    operation = extract_operation(metadata.query)

    record("database_queries_total", 1, %{
      repo: repo,
      operation: operation
    })

    if total_time = measurements[:total_time] do
      duration_seconds = System.convert_time_unit(total_time, :native, :microsecond) / 1_000_000

      record("database_query_duration_seconds", duration_seconds, %{
        repo: repo,
        operation: operation
      })
    end
  end

  defp handle_event_store_metrics([:event_store, operation], measurements, metadata, _config) do
    status = if metadata[:error], do: "error", else: "success"

    record("event_store_operations_total", 1, %{
      operation: to_string(operation),
      status: status
    })

    # ストリーム長の更新
    if operation == :append do
      if aggregate_type = metadata[:aggregate_type] do
        if stream_length = metadata[:stream_length] do
          record("event_store_stream_length", stream_length, %{
            aggregate_type: to_string(aggregate_type)
          })
        end
      end
    end
  end

  defp update_metric(metrics, name, value, labels) do
    key = {name, labels}

    case get_metric_type(name) do
      :counter ->
        Map.update(metrics, key, value, &(&1 + value))

      :gauge ->
        Map.put(metrics, key, value)

      :histogram ->
        current = Map.get(metrics, key, %{sum: 0, count: 0, buckets: %{}})

        updated = %{
          sum: current.sum + value,
          count: current.count + 1,
          buckets: update_histogram_buckets(current.buckets, value, name)
        }

        Map.put(metrics, key, updated)
    end
  end

  defp update_histogram_buckets(buckets, value, metric_name) do
    bucket_bounds = get_bucket_bounds(metric_name)

    Enum.reduce(bucket_bounds, buckets, fn bound, acc ->
      if value <= bound do
        Map.update(acc, bound, 1, &(&1 + 1))
      else
        acc
      end
    end)
  end

  defp get_metric_type(name) do
    Enum.find_value(@metrics, fn
      {type, ^name, _, _} -> type
      {type, ^name, _, _, _} -> type
      _ -> nil
    end)
  end

  defp get_bucket_bounds(metric_name) do
    Enum.find_value(@metrics, fn
      {:histogram, ^metric_name, _, _, buckets: bounds} -> bounds
      _ -> nil
    end) || [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
  end

  defp build_prometheus_output(metrics) do
    @metrics
    |> Enum.map(&format_metric(&1, metrics))
    |> Enum.join("\n")
  end

  defp format_metric({type, name, help, labels}, metrics) when type in [:counter, :gauge] do
    """
    # HELP #{name} #{help}
    # TYPE #{name} #{type}
    #{format_metric_values(name, labels, metrics, type)}
    """
  end

  defp format_metric({:histogram, name, help, labels, buckets: bucket_bounds}, metrics) do
    """
    # HELP #{name} #{help}
    # TYPE #{name} histogram
    #{format_histogram_values(name, labels, metrics, bucket_bounds)}
    """
  end

  defp format_metric_values(name, label_keys, metrics, _type) do
    metrics
    |> Enum.filter(fn {{metric_name, _}, _} -> metric_name == name end)
    |> Enum.map(fn {{_, labels}, value} ->
      label_str = format_labels(label_keys, labels)
      "#{name}#{label_str} #{value}"
    end)
    |> Enum.join("\n")
  end

  defp format_histogram_values(name, label_keys, metrics, bucket_bounds) do
    metrics
    |> Enum.filter(fn {{metric_name, _}, _} -> metric_name == name end)
    |> Enum.flat_map(fn {{_, labels}, histogram_data} ->
      label_str = format_labels(label_keys, labels)

      bucket_lines =
        bucket_bounds
        |> Enum.map(fn bound ->
          count = Map.get(histogram_data.buckets, bound, 0)
          "#{name}_bucket{#{label_str},le=\"#{bound}\"} #{count}"
        end)

      bucket_lines ++
        [
          "#{name}_bucket{#{label_str},le=\"+Inf\"} #{histogram_data.count}",
          "#{name}_sum#{label_str} #{histogram_data.sum}",
          "#{name}_count#{label_str} #{histogram_data.count}"
        ]
    end)
    |> Enum.join("\n")
  end

  defp format_labels(label_keys, label_values) do
    labels =
      label_keys
      |> Enum.map(fn key ->
        value = Map.get(label_values, key, "")
        ~s(#{key}="#{escape_label_value(value)}")
      end)
      |> Enum.join(",")

    if labels == "", do: "", else: "{#{labels}}"
  end

  defp escape_label_value(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  defp normalize_path(path) do
    path
    |> String.split("/")
    |> Enum.map(fn segment ->
      if String.match?(
           segment,
           ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
         ) do
        ":id"
      else
        segment
      end
    end)
    |> Enum.join("/")
  end

  defp extract_operation(query) do
    cond do
      String.starts_with?(query, "SELECT") -> "select"
      String.starts_with?(query, "INSERT") -> "insert"
      String.starts_with?(query, "UPDATE") -> "update"
      String.starts_with?(query, "DELETE") -> "delete"
      true -> "other"
    end
  end

  defp schedule_system_metrics do
    Process.send_after(self(), :collect_system_metrics, :timer.seconds(15))
  end
end
