defmodule Shared.Telemetry.Metrics.Collector do
  @moduledoc """
  メトリクス収集とカスタムメトリクスの定義

  アプリケーション固有のメトリクスを収集し、Prometheus エクスポーターに送信します。
  """

  alias Shared.Telemetry.Metrics.PrometheusExporter

  require Logger

  @doc """
  カスタムメトリクスを記録
  """
  def record_metric(name, value, labels \\ %{}) do
    PrometheusExporter.record(name, value, labels)
  end

  @doc """
  コマンド実行メトリクスを記録
  """
  def record_command_execution(command_type, duration_ms, success?) do
    status = if success?, do: "success", else: "error"

    # Telemetry イベントを発行
    :telemetry.execute(
      [:cqrs, :command, :stop],
      # マイクロ秒に変換
      %{duration: duration_ms * 1_000},
      %{
        command_type: command_type,
        error: not success?
      }
    )
  end

  @doc """
  イベント発行メトリクスを記録
  """
  def record_event_published(event_type) do
    :telemetry.execute(
      [:cqrs, :event, :published],
      %{},
      %{event_type: event_type}
    )
  end

  @doc """
  イベント処理メトリクスを記録
  """
  def record_event_processed(event_type, handler, success?) do
    :telemetry.execute(
      [:cqrs, :event, :processed],
      %{},
      %{
        event_type: event_type,
        handler: handler,
        error: not success?
      }
    )
  end

  @doc """
  Saga メトリクスを記録
  """
  def record_saga_started(saga_type) do
    :telemetry.execute(
      [:saga, :started],
      %{},
      %{saga_type: saga_type}
    )
  end

  def record_saga_completed(saga_type, duration_ms, success?) do
    event = if success?, do: :completed, else: :failed

    :telemetry.execute(
      [:saga, event],
      %{duration: duration_ms * 1_000},
      %{saga_type: saga_type}
    )
  end

  def record_saga_step(saga_type, step_name, duration_ms, success?) do
    event = if success?, do: :step_completed, else: :step_failed

    :telemetry.execute(
      [:saga, event],
      %{duration: duration_ms * 1_000},
      %{
        saga_type: saga_type,
        step_name: step_name
      }
    )
  end

  @doc """
  サーキットブレーカー状態変更を記録
  """
  def record_circuit_breaker_state_change(service, from_state, to_state) do
    record_metric("circuit_breaker_state_changes_total", 1, %{
      service: service,
      from_state: to_string(from_state),
      to_state: to_string(to_state)
    })

    # 現在の状態をゲージとして記録
    state_value =
      case to_state do
        :closed -> 0
        :open -> 1
        :half_open -> 2
      end

    record_metric("circuit_breaker_state", state_value, %{service: service})
  end

  @doc """
  デッドレターキューメトリクスを記録
  """
  def record_dlq_message(queue, reason) do
    record_metric("dead_letter_queue_messages_total", 1, %{
      queue: queue,
      reason: reason
    })
  end

  def update_dlq_size(queue, size) do
    record_metric("dead_letter_queue_size", size, %{queue: queue})
  end

  @doc """
  イベントストアメトリクスを記録
  """
  def record_event_store_operation(operation, success?, metadata \\ %{}) do
    status = if success?, do: "success", else: "error"

    base_metadata = %{
      operation: to_string(operation),
      error: not success?
    }

    :telemetry.execute(
      [:event_store, operation],
      %{},
      Map.merge(base_metadata, metadata)
    )
  end

  @doc """
  ビジネスメトリクスを記録
  """
  def record_business_metric(metric_name, value, labels \\ %{}) do
    # ビジネスメトリクス用のプレフィックスを追加
    full_name = "business_#{metric_name}"
    record_metric(full_name, value, labels)
  end

  @doc """
  注文関連のビジネスメトリクス
  """
  def record_order_created(user_id, total_amount) do
    record_business_metric("orders_created_total", 1, %{})
    record_business_metric("order_total_amount", total_amount, %{})
  end

  def record_order_completed(user_id, total_amount, duration_ms) do
    record_business_metric("orders_completed_total", 1, %{})
    record_business_metric("order_completion_time_seconds", duration_ms / 1000, %{})
  end

  def record_order_cancelled(user_id, reason) do
    record_business_metric("orders_cancelled_total", 1, %{reason: reason})
  end

  @doc """
  在庫関連のビジネスメトリクス
  """
  def record_stock_reserved(product_id, quantity) do
    record_business_metric("stock_reserved_total", quantity, %{product_id: product_id})
  end

  def record_stock_released(product_id, quantity) do
    record_business_metric("stock_released_total", quantity, %{product_id: product_id})
  end

  def update_stock_level(product_id, current_level) do
    record_business_metric("stock_level_current", current_level, %{product_id: product_id})
  end

  @doc """
  支払い関連のビジネスメトリクス
  """
  def record_payment_processed(amount, payment_method, success?) do
    status = if success?, do: "success", else: "failed"

    record_business_metric("payments_total", 1, %{
      payment_method: payment_method,
      status: status
    })

    if success? do
      record_business_metric("payment_amount_total", amount, %{
        payment_method: payment_method
      })
    end
  end

  @doc """
  カスタムカウンターを増やす
  """
  def increment_counter(name, labels \\ %{}, amount \\ 1) do
    record_metric(name, amount, labels)
  end

  @doc """
  カスタムゲージを設定
  """
  def set_gauge(name, value, labels \\ %{}) do
    record_metric(name, value, labels)
  end

  @doc """
  カスタムヒストグラムに値を記録
  """
  def observe_histogram(name, value, labels \\ %{}) do
    record_metric(name, value, labels)
  end

  @doc """
  タイミング計測のヘルパー関数
  """
  def time_operation(name, labels \\ %{}, fun) do
    start_time = System.monotonic_time()

    try do
      result = fun.()

      duration_ms =
        System.convert_time_unit(
          System.monotonic_time() - start_time,
          :native,
          :millisecond
        )

      observe_histogram(name, duration_ms / 1000, labels)
      {:ok, result, duration_ms}
    rescue
      e ->
        duration_ms =
          System.convert_time_unit(
            System.monotonic_time() - start_time,
            :native,
            :millisecond
          )

        observe_histogram(name, duration_ms / 1000, Map.put(labels, :error, "true"))
        {:error, e, duration_ms}
    end
  end
end
