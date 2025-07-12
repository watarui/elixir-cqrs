defmodule ClientService.GraphQL.Types.Metrics do
  @moduledoc """
  GraphQL types for Prometheus metrics
  """

  use Absinthe.Schema.Notation

  @desc "Prometheus metric type"
  enum :metric_type do
    value(:counter, description: "Monotonically increasing counter")
    value(:gauge, description: "Value that can go up and down")
    value(:histogram, description: "Distribution of values")
    value(:summary, description: "Statistical distribution")
  end

  @desc "Metric label"
  object :metric_label do
    field(:name, non_null(:string))
    field(:value, non_null(:string))
  end

  @desc "Prometheus metric"
  object :prometheus_metric do
    field(:name, non_null(:string))
    field(:help, :string)
    field(:type, non_null(:metric_type))
    field(:value, :float)
    field(:labels, list_of(:metric_label))
    field(:timestamp, :datetime)
  end

  @desc "Metric series (time series data)"
  object :metric_series do
    field(:metric_name, non_null(:string))
    field(:labels, list_of(:metric_label))
    field(:values, list_of(:metric_value))
  end

  @desc "Metric value with timestamp"
  object :metric_value do
    field(:timestamp, non_null(:datetime))
    field(:value, non_null(:float))
  end

  @desc "System metrics"
  object :system_metrics do
    field(:cpu_usage, :float)
    field(:memory_usage, :float)
    field(:disk_usage, :float)
    field(:network_io, :network_io)
    field(:process_count, :integer)
    field(:thread_count, :integer)
  end

  @desc "Network I/O stats"
  object :network_io do
    field(:bytes_in, :integer)
    field(:bytes_out, :integer)
    field(:packets_in, :integer)
    field(:packets_out, :integer)
  end

  @desc "Application metrics"
  object :application_metrics do
    field(:http_requests_total, :integer)
    field(:http_request_duration_p50, :float)
    field(:http_request_duration_p95, :float)
    field(:http_request_duration_p99, :float)
    field(:error_rate, :float)
    field(:active_connections, :integer)
  end

  @desc "CQRS metrics"
  object :cqrs_metrics do
    field(:commands_total, :integer)
    field(:commands_per_second, :float)
    field(:command_error_rate, :float)
    field(:events_total, :integer)
    field(:events_per_second, :float)
    field(:queries_total, :integer)
    field(:queries_per_second, :float)
  end

  @desc "Saga metrics"
  object :saga_metrics do
    field(:active_sagas, :integer)
    field(:completed_sagas, :integer)
    field(:failed_sagas, :integer)
    field(:compensated_sagas, :integer)
    field(:saga_duration_p50, :float)
    field(:saga_duration_p95, :float)
  end

  @desc "All metrics combined"
  object :metrics_overview do
    field(:system, :system_metrics)
    field(:application, :application_metrics)
    field(:cqrs, :cqrs_metrics)
    field(:saga, :saga_metrics)
    field(:timestamp, non_null(:datetime))
  end
end
