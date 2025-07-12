defmodule Shared.Telemetry.Metrics.Dashboard do
  @moduledoc """
  メトリクスダッシュボードの定義

  Telemetry.Metrics を使用してダッシュボードを定義します。
  """

  import Telemetry.Metrics

  @doc """
  ダッシュボード用のメトリクス定義
  """
  def metrics do
    [
      # HTTP メトリクス
      http_metrics(),

      # コマンド/クエリメトリクス
      cqrs_metrics(),

      # Saga メトリクス
      saga_metrics(),

      # イベントストアメトリクス
      event_store_metrics(),

      # システムメトリクス
      system_metrics(),

      # ビジネスメトリクス
      business_metrics()
    ]
    |> List.flatten()
  end

  defp http_metrics do
    [
      # リクエスト率
      counter("phoenix.endpoint.stop.duration",
        tags: [:method, :route],
        tag_values: &tag_method_and_route/1,
        description: "HTTP request count"
      ),

      # レスポンスタイム分布
      distribution("phoenix.endpoint.stop.duration",
        tags: [:method, :route],
        tag_values: &tag_method_and_route/1,
        unit: {:native, :millisecond},
        description: "HTTP request duration"
      ),

      # エラー率
      counter("phoenix.endpoint.stop.duration",
        tags: [:method, :route, :status],
        tag_values: &tag_method_route_status/1,
        description: "HTTP request by status"
      ),

      # 現在の接続数
      last_value("phoenix.endpoint.connection_count",
        description: "Current number of connections"
      )
    ]
  end

  defp cqrs_metrics do
    [
      # コマンド実行数
      counter("cqrs.command.stop.duration",
        tags: [:command_type, :status],
        tag_values: &tag_command_status/1,
        description: "Command execution count"
      ),

      # コマンド実行時間
      distribution("cqrs.command.stop.duration",
        tags: [:command_type],
        tag_values: &tag_command_type/1,
        unit: {:native, :millisecond},
        description: "Command execution duration"
      ),

      # イベント発行数
      counter("cqrs.event.published",
        tags: [:event_type],
        tag_values: &tag_event_type/1,
        description: "Events published"
      ),

      # イベント処理数
      counter("cqrs.event.processed",
        tags: [:event_type, :handler, :status],
        tag_values: &tag_event_handler_status/1,
        description: "Events processed"
      )
    ]
  end

  defp saga_metrics do
    [
      # Saga 開始数
      counter("saga.started",
        tags: [:saga_type],
        tag_values: &tag_saga_type/1,
        description: "Sagas started"
      ),

      # Saga 完了数
      counter("saga.completed",
        tags: [:saga_type],
        tag_values: &tag_saga_type/1,
        description: "Sagas completed"
      ),

      # Saga 失敗数
      counter("saga.failed",
        tags: [:saga_type],
        tag_values: &tag_saga_type/1,
        description: "Sagas failed"
      ),

      # Saga 実行時間
      distribution("saga.completed.duration",
        tags: [:saga_type],
        tag_values: &tag_saga_type/1,
        unit: {:native, :second},
        description: "Saga execution duration"
      ),

      # Saga ステップ実行時間
      distribution("saga.step_completed.duration",
        tags: [:saga_type, :step_name],
        tag_values: &tag_saga_step/1,
        unit: {:native, :millisecond},
        description: "Saga step execution duration"
      )
    ]
  end

  defp event_store_metrics do
    [
      # イベントストア操作数
      counter("event_store.append",
        tags: [:status],
        tag_values: &tag_status/1,
        description: "Event store append operations"
      ),
      counter("event_store.read",
        tags: [:status],
        tag_values: &tag_status/1,
        description: "Event store read operations"
      ),

      # ストリーム長
      last_value("event_store.stream_length",
        tags: [:aggregate_type],
        tag_values: &tag_aggregate_type/1,
        description: "Event stream length"
      )
    ]
  end

  defp system_metrics do
    [
      # VM メモリ使用量
      last_value("vm.memory.total",
        unit: :byte,
        description: "Total memory used by the Erlang VM"
      ),
      last_value("vm.memory.processes",
        unit: :byte,
        description: "Memory used by Erlang processes"
      ),
      last_value("vm.memory.binary",
        unit: :byte,
        description: "Memory used by binaries"
      ),
      last_value("vm.memory.ets",
        unit: :byte,
        description: "Memory used by ETS tables"
      ),

      # プロセス数
      last_value("vm.total_run_queue_lengths.total",
        description: "Total run queue lengths"
      ),
      last_value("vm.total_process_count",
        description: "Total number of processes"
      ),

      # GC メトリクス
      summary("vm.gc.runs",
        tags: [:type],
        tag_values: fn metadata -> %{type: metadata[:type] || "unknown"} end,
        description: "Garbage collection runs"
      ),

      # データベースプール
      last_value("ecto.pool.size",
        tags: [:repo],
        tag_values: &tag_repo/1,
        description: "Database connection pool size"
      ),
      last_value("ecto.pool.queue_size",
        tags: [:repo],
        tag_values: &tag_repo/1,
        description: "Database connection queue size"
      )
    ]
  end

  defp business_metrics do
    [
      # 注文メトリクス
      counter("business.orders_created_total",
        description: "Total orders created"
      ),
      counter("business.orders_completed_total",
        description: "Total orders completed"
      ),
      counter("business.orders_cancelled_total",
        tags: [:reason],
        tag_values: fn metadata -> %{reason: metadata[:reason] || "unknown"} end,
        description: "Total orders cancelled"
      ),
      distribution("business.order_total_amount",
        unit: :dollar,
        description: "Order total amount distribution"
      ),
      distribution("business.order_completion_time_seconds",
        unit: :second,
        description: "Order completion time"
      ),

      # 在庫メトリクス
      counter("business.stock_reserved_total",
        tags: [:product_id],
        tag_values: fn metadata -> %{product_id: metadata[:product_id] || "unknown"} end,
        description: "Total stock reserved"
      ),
      last_value("business.stock_level_current",
        tags: [:product_id],
        tag_values: fn metadata -> %{product_id: metadata[:product_id] || "unknown"} end,
        description: "Current stock level"
      ),

      # 支払いメトリクス
      counter("business.payments_total",
        tags: [:payment_method, :status],
        tag_values: fn metadata ->
          %{
            payment_method: metadata[:payment_method] || "unknown",
            status: metadata[:status] || "unknown"
          }
        end,
        description: "Total payments processed"
      ),
      sum("business.payment_amount_total",
        tags: [:payment_method],
        tag_values: fn metadata -> %{payment_method: metadata[:payment_method] || "unknown"} end,
        unit: :dollar,
        description: "Total payment amount"
      )
    ]
  end

  # タグ値抽出ヘルパー関数

  defp tag_method_and_route(metadata) do
    %{
      method: metadata.conn.method,
      route: metadata.route || metadata.conn.request_path
    }
  end

  defp tag_method_route_status(metadata) do
    %{
      method: metadata.conn.method,
      route: metadata.route || metadata.conn.request_path,
      status: Integer.to_string(metadata.conn.status)
    }
  end

  defp tag_command_type(metadata) do
    %{command_type: metadata[:command_type] || "unknown"}
  end

  defp tag_command_status(metadata) do
    status = if metadata[:error], do: "error", else: "success"

    %{
      command_type: metadata[:command_type] || "unknown",
      status: status
    }
  end

  defp tag_event_type(metadata) do
    %{event_type: metadata[:event_type] || "unknown"}
  end

  defp tag_event_handler_status(metadata) do
    status = if metadata[:error], do: "error", else: "success"

    %{
      event_type: metadata[:event_type] || "unknown",
      handler: metadata[:handler] || "unknown",
      status: status
    }
  end

  defp tag_saga_type(metadata) do
    %{saga_type: metadata[:saga_type] || "unknown"}
  end

  defp tag_saga_step(metadata) do
    %{
      saga_type: metadata[:saga_type] || "unknown",
      step_name: metadata[:step_name] || "unknown"
    }
  end

  defp tag_status(metadata) do
    status = if metadata[:error], do: "error", else: "success"
    %{status: status}
  end

  defp tag_aggregate_type(metadata) do
    %{aggregate_type: metadata[:aggregate_type] || "unknown"}
  end

  defp tag_repo(metadata) do
    repo = metadata[:repo] |> Module.split() |> List.last()
    %{repo: repo}
  end
end
