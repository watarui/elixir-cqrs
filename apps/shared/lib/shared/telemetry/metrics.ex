defmodule Shared.Telemetry.Metrics do
  @moduledoc """
  アプリケーション全体のメトリクス定義
  """
  
  import Telemetry.Metrics
  
  @doc """
  監視すべきメトリクスのリストを返す
  """
  def metrics do
    [
      # Phoenix メトリクス
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        tags: [:route]
      ),
      counter("phoenix.endpoint.stop.count",
        tags: [:method, :route, :status]
      ),
      
      # GraphQL メトリクス
      summary("absinthe.execute.operation.stop.duration",
        unit: {:native, :millisecond},
        tags: [:operation_type, :operation_name]
      ),
      counter("absinthe.execute.operation.stop.count",
        tags: [:operation_type]
      ),
      
      # Ecto メトリクス
      summary("command_service.repo.query.total_time",
        unit: {:native, :millisecond},
        tags: [:query]
      ),
      summary("query_service.repo.query.total_time",
        unit: {:native, :millisecond},
        tags: [:query]
      ),
      counter("command_service.repo.query.count",
        tags: [:query]
      ),
      counter("query_service.repo.query.count",
        tags: [:query]
      ),
      
      # gRPC メトリクス
      summary("grpc.server.rpc.duration",
        unit: {:native, :millisecond},
        tags: [:service, :method, :status]
      ),
      counter("grpc.server.rpc.count",
        tags: [:service, :method, :status]
      ),
      summary("grpc.client.rpc.duration",
        unit: {:native, :millisecond},
        tags: [:service, :method, :status]
      ),
      counter("grpc.client.rpc.count",
        tags: [:service, :method, :status]
      ),
      
      # レジリエンスメトリクス
      counter("grpc.retry.count",
        tags: [:status]
      ),
      summary("grpc.retry.duration",
        unit: {:native, :millisecond}
      ),
      counter("grpc.client.call.count",
        tags: [:operation, :status, :error]
      ),
      summary("grpc.client.call.duration",
        unit: {:native, :millisecond},
        tags: [:operation, :status]
      ),
      counter("circuit_breaker.call.count",
        tags: [:circuit_breaker, :status]
      ),
      summary("circuit_breaker.call.latency",
        unit: {:native, :millisecond},
        tags: [:circuit_breaker, :status]
      ),
      
      # ビジネスメトリクス
      counter("command.execute.count",
        tags: [:command_type, :status]
      ),
      summary("command.execute.duration",
        unit: {:native, :millisecond},
        tags: [:command_type]
      ),
      counter("query.execute.count",
        tags: [:query_type, :status]
      ),
      summary("query.execute.duration",
        unit: {:native, :millisecond},
        tags: [:query_type]
      ),
      counter("event.publish.count",
        tags: [:event_type]
      ),
      
      # カスタムメトリクス
      counter("product.created.count"),
      counter("product.updated.count"),
      counter("product.deleted.count"),
      counter("category.created.count"),
      counter("category.updated.count"),
      counter("category.deleted.count"),
      
      # システムメトリクス
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.system_counts.process_count")
    ] ++ Shared.Telemetry.SagaMetrics.metrics()
  end
  
  @doc """
  Prometheusエクスポート用のメトリクス
  """
  def prometheus_metrics do
    [
      # HTTPレスポンスタイム
      distribution("http.request.duration",
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]],
        unit: {:native, :millisecond},
        tags: [:method, :route, :status]
      ),
      
      # gRPCレスポンスタイム
      distribution("grpc.request.duration",
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]],
        unit: {:native, :millisecond},
        tags: [:service, :method, :status]
      ),
      
      # データベースクエリタイム
      distribution("db.query.duration",
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1000]],
        unit: {:native, :millisecond},
        tags: [:repo, :query_type]
      )
    ]
  end
end