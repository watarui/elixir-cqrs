defmodule Shared.Telemetry.Setup do
  @moduledoc """
  OpenTelemetryとTelemetryの共通設定
  """
  
  require Logger
  
  @doc """
  OpenTelemetryの初期化
  """
  def setup_opentelemetry do
    # OpenTelemetry設定
    :opentelemetry.set_default_tracer(:elixir_cqrs)
    
    # Jaegerエクスポーター設定
    :opentelemetry.register_tracer(:elixir_cqrs, "0.1.0")
    
    Logger.info("OpenTelemetry initialized")
  end
  
  @doc """
  共通のTelemetryイベントハンドラーを設定
  """
  def attach_telemetry_handlers do
    # データベースクエリのトレース
    :telemetry.attach_many(
      "elixir-cqrs-db-handler",
      [
        [:ecto, :query],
        [:ecto, :query, :queue_time],
        [:ecto, :query, :query_time],
        [:ecto, :query, :decode_time]
      ],
      &handle_db_event/4,
      nil
    )
    
    # HTTPリクエストのトレース
    :telemetry.attach_many(
      "elixir-cqrs-http-handler",
      [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop]
      ],
      &handle_http_event/4,
      nil
    )
    
    # gRPCリクエストのトレース
    :telemetry.attach_many(
      "elixir-cqrs-grpc-handler",
      [
        [:grpc, :server, :rpc, :start],
        [:grpc, :server, :rpc, :stop],
        [:grpc, :client, :rpc, :start],
        [:grpc, :client, :rpc, :stop]
      ],
      &handle_grpc_event/4,
      nil
    )
    
    # ビジネスイベントのトレース
    :telemetry.attach_many(
      "elixir-cqrs-business-handler",
      [
        [:command, :execute, :start],
        [:command, :execute, :stop],
        [:query, :execute, :start],
        [:query, :execute, :stop],
        [:event, :publish, :start],
        [:event, :publish, :stop]
      ],
      &handle_business_event/4,
      nil
    )
    
    # gRPCリトライとサーキットブレーカーのトレース
    :telemetry.attach_many(
      "elixir-cqrs-resilience-handler",
      [
        [:grpc, :retry],
        [:grpc, :client, :call],
        [:circuit_breaker, :call]
      ],
      &handle_resilience_event/4,
      nil
    )
    
    Logger.info("Telemetry handlers attached")
  end
  
  # データベースイベントハンドラー
  defp handle_db_event(event_name, measurements, metadata, _config) do
    Logger.debug("Database event",
      event: event_name,
      measurements: measurements,
      query: metadata[:query],
      source: metadata[:source],
      duration_ms: measurements[:query_time] && System.convert_time_unit(measurements[:query_time], :native, :millisecond)
    )
  end
  
  # HTTPイベントハンドラー
  defp handle_http_event(event_name, measurements, metadata, _config) do
    Logger.debug("HTTP event",
      event: event_name,
      measurements: measurements,
      method: metadata[:conn] && metadata[:conn].method,
      path: metadata[:conn] && metadata[:conn].request_path,
      status: metadata[:conn] && metadata[:conn].status,
      duration_ms: measurements[:duration] && System.convert_time_unit(measurements[:duration], :native, :millisecond)
    )
  end
  
  # gRPCイベントハンドラー
  defp handle_grpc_event(event_name, measurements, metadata, _config) do
    Logger.debug("gRPC event",
      event: event_name,
      measurements: measurements,
      service: metadata[:service],
      method: metadata[:method],
      status: metadata[:status],
      duration_ms: measurements[:duration] && System.convert_time_unit(measurements[:duration], :native, :millisecond)
    )
  end
  
  # ビジネスイベントハンドラー
  defp handle_business_event(event_name, measurements, metadata, _config) do
    Logger.info("Business event",
      event: event_name,
      measurements: measurements,
      type: metadata[:type],
      aggregate_id: metadata[:aggregate_id],
      user_id: metadata[:user_id],
      duration_ms: measurements[:duration] && System.convert_time_unit(measurements[:duration], :native, :millisecond)
    )
  end
  
  # レジリエンスイベントハンドラー
  defp handle_resilience_event(event_name, measurements, metadata, _config) do
    case event_name do
      [:grpc, :retry] ->
        Logger.warning("gRPC retry event",
          status: metadata[:status],
          attempt: measurements[:attempt_count],
          duration_ms: measurements[:duration]
        )
        
      [:grpc, :client, :call] ->
        if metadata[:error] do
          Logger.error("gRPC client call failed",
            operation: metadata[:metadata] && metadata[:metadata][:operation],
            status: metadata[:status],
            duration_ms: measurements[:duration]
          )
        else
          Logger.debug("gRPC client call succeeded",
            operation: metadata[:metadata] && metadata[:metadata][:operation],
            duration_ms: measurements[:duration]
          )
        end
        
      [:circuit_breaker, :call] ->
        Logger.info("Circuit breaker event",
          circuit: metadata[:circuit_breaker],
          status: metadata[:status],
          latency_ms: measurements[:latency]
        )
    end
  end
  
  @doc """
  カスタムメトリクスを記録
  """
  def record_metric(metric_name, value, tags \\ %{}) do
    :telemetry.execute(
      [:elixir_cqrs, :custom, metric_name],
      %{value: value},
      tags
    )
  end
  
  @doc """
  ビジネスイベントを記録
  """
  def record_business_event(event_type, metadata \\ %{}) do
    :telemetry.execute(
      [:elixir_cqrs, :business, event_type],
      %{count: 1},
      metadata
    )
  end
end