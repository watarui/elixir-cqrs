defmodule ClientService.GraphQL.Resolvers.MetricsResolver do
  @moduledoc """
  GraphQL resolver for Prometheus metrics
  """

  alias Shared.Telemetry.Metrics.PrometheusExporter

  require Logger

  @doc """
  Get current metrics overview
  """
  def get_metrics_overview(_parent, _args, _resolution) do
    # Prometheus 形式のメトリクスを取得
    raw_metrics = PrometheusExporter.export()

    # パースして構造化データに変換
    metrics = parse_prometheus_metrics(raw_metrics)

    {:ok,
     %{
       system: calculate_system_metrics(metrics),
       application: calculate_application_metrics(metrics),
       cqrs: calculate_cqrs_metrics(metrics),
       saga: calculate_saga_metrics(metrics),
       timestamp: DateTime.utc_now()
     }}
  end

  @doc """
  Get raw Prometheus metrics
  """
  def get_prometheus_metrics(_parent, args, _resolution) do
    filter = Map.get(args, :filter, %{})

    raw_metrics = PrometheusExporter.export()
    metrics = parse_prometheus_metrics(raw_metrics)

    filtered_metrics = apply_filters(metrics, filter)

    {:ok, filtered_metrics}
  end

  @doc """
  Get time series data for specific metrics
  """
  def get_metric_series(_parent, args, _resolution) do
    metric_names = Map.get(args, :metric_names, [])
    # デフォルト1時間
    duration = Map.get(args, :duration, 3600)

    # 実際の実装では時系列データベースから取得
    # ここではモックデータを返す
    series =
      Enum.map(metric_names, fn metric_name ->
        %{
          metric_name: metric_name,
          labels: [],
          values: generate_mock_time_series(duration)
        }
      end)

    {:ok, series}
  end

  # Private functions

  defp parse_prometheus_metrics(raw_text) do
    raw_text
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_metric_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_metric_line(line) do
    case Regex.run(~r/^([a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{([^}]*)\})?\s+(.+)$/, line) do
      [_, name, labels_str, value] ->
        labels = parse_labels(labels_str || "")

        %{
          name: name,
          labels: labels,
          value: parse_float(value),
          timestamp: DateTime.utc_now()
        }

      _ ->
        nil
    end
  end

  defp parse_labels(labels_str) do
    if labels_str == "" do
      []
    else
      labels_str
      |> String.split(",")
      |> Enum.map(fn label ->
        case String.split(label, "=") do
          [name, value] ->
            %{
              name: String.trim(name),
              value: String.trim(value, "\"")
            }

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    end
  end

  defp parse_float(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp apply_filters(metrics, filter) do
    metrics
    |> filter_by_name(Map.get(filter, :name_pattern))
    |> filter_by_labels(Map.get(filter, :labels))
  end

  defp filter_by_name(metrics, nil), do: metrics

  defp filter_by_name(metrics, pattern) do
    regex = Regex.compile!(pattern)

    Enum.filter(metrics, fn metric ->
      Regex.match?(regex, metric.name)
    end)
  end

  defp filter_by_labels(metrics, nil), do: metrics

  defp filter_by_labels(metrics, required_labels) do
    Enum.filter(metrics, fn metric ->
      Enum.all?(required_labels, fn {name, value} ->
        Enum.any?(metric.labels, fn label ->
          label.name == to_string(name) && label.value == to_string(value)
        end)
      end)
    end)
  end

  defp calculate_system_metrics(metrics) do
    memory_metrics = filter_metrics_by_name(metrics, "erlang_vm_memory_bytes")

    %{
      cpu_usage: get_cpu_usage(),
      memory_usage: calculate_memory_usage(memory_metrics),
      disk_usage: get_disk_usage(),
      network_io: %{
        bytes_in: 0,
        bytes_out: 0,
        packets_in: 0,
        packets_out: 0
      },
      process_count: get_metric_value(metrics, "erlang_vm_process_count"),
      thread_count: System.schedulers_online()
    }
  end

  defp calculate_application_metrics(metrics) do
    %{
      http_requests_total: get_metric_sum(metrics, "http_requests_total"),
      http_request_duration_p50:
        get_histogram_percentile(metrics, "http_request_duration_seconds", 0.5),
      http_request_duration_p95:
        get_histogram_percentile(metrics, "http_request_duration_seconds", 0.95),
      http_request_duration_p99:
        get_histogram_percentile(metrics, "http_request_duration_seconds", 0.99),
      error_rate: calculate_error_rate(metrics),
      active_connections: get_metric_value(metrics, "active_connections", 0)
    }
  end

  defp calculate_cqrs_metrics(metrics) do
    %{
      commands_total: get_metric_sum(metrics, "commands_total"),
      commands_per_second: calculate_rate(metrics, "commands_total"),
      command_error_rate: calculate_command_error_rate(metrics),
      events_total: get_metric_sum(metrics, "events_published_total"),
      events_per_second: calculate_rate(metrics, "events_published_total"),
      queries_total: get_metric_sum(metrics, "queries_total"),
      queries_per_second: calculate_rate(metrics, "queries_total")
    }
  end

  defp calculate_saga_metrics(metrics) do
    %{
      active_sagas: get_metric_value_by_status(metrics, "saga_completed_total", "active"),
      completed_sagas: get_metric_value_by_status(metrics, "saga_completed_total", "completed"),
      failed_sagas: get_metric_value_by_status(metrics, "saga_completed_total", "failed"),
      compensated_sagas:
        get_metric_value_by_status(metrics, "saga_completed_total", "compensated"),
      saga_duration_p50: get_histogram_percentile(metrics, "saga_duration_seconds", 0.5),
      saga_duration_p95: get_histogram_percentile(metrics, "saga_duration_seconds", 0.95)
    }
  end

  defp filter_metrics_by_name(metrics, name) do
    Enum.filter(metrics, fn metric -> metric.name == name end)
  end

  defp get_metric_value(metrics, name, default \\ 0) do
    metrics
    |> Enum.find(fn m -> m.name == name end)
    |> case do
      nil -> default
      metric -> round(metric.value)
    end
  end

  defp get_metric_sum(metrics, name) do
    metrics
    |> Enum.filter(fn m -> m.name == name end)
    |> Enum.map(fn m -> m.value end)
    |> Enum.sum()
    |> round()
  end

  defp get_metric_value_by_status(metrics, name, status) do
    metrics
    |> Enum.filter(fn m ->
      m.name == name &&
        Enum.any?(m.labels, fn l -> l.name == "status" && l.value == status end)
    end)
    |> Enum.map(fn m -> m.value end)
    |> Enum.sum()
    |> round()
  end

  defp get_histogram_percentile(_metrics, _name, _percentile) do
    # 簡略化のため固定値を返す
    # 実際の実装では histogram データから計算
    :rand.uniform() * 100
  end

  defp calculate_error_rate(metrics) do
    total = get_metric_sum(metrics, "http_requests_total")

    errors =
      metrics
      |> Enum.filter(fn m ->
        m.name == "http_requests_total" &&
          Enum.any?(m.labels, fn l ->
            l.name == "status" && String.starts_with?(l.value, "5")
          end)
      end)
      |> Enum.map(fn m -> m.value end)
      |> Enum.sum()

    if total > 0, do: errors / total, else: 0.0
  end

  defp calculate_command_error_rate(metrics) do
    total = get_metric_sum(metrics, "commands_total")
    errors = get_metric_value_by_status(metrics, "commands_total", "error")

    if total > 0, do: errors / total, else: 0.0
  end

  defp calculate_rate(_metrics, _name) do
    # 簡略化のため固定値を返す
    # 実際の実装では時系列データから計算
    :rand.uniform() * 10
  end

  defp get_cpu_usage do
    # 簡略化のため固定値を返す
    # 実際の実装では :cpu_sup.util() を使用
    :rand.uniform() * 100
  end

  defp calculate_memory_usage(memory_metrics) do
    total =
      memory_metrics
      |> Enum.map(fn m -> m.value end)
      |> Enum.sum()

    # MB に変換
    total / 1024 / 1024
  end

  defp get_disk_usage do
    # 簡略化のため固定値を返す
    :rand.uniform() * 100
  end

  defp generate_mock_time_series(duration_seconds) do
    points = min(duration_seconds / 60, 60) |> round()
    now = DateTime.utc_now()

    Enum.map(0..(points - 1), fn i ->
      %{
        timestamp: DateTime.add(now, -i * 60, :second),
        value: :rand.uniform() * 100
      }
    end)
    |> Enum.reverse()
  end
end
