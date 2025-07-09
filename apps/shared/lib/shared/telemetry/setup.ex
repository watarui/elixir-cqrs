defmodule Shared.Telemetry.Setup do
  @moduledoc """
  OpenTelemetry のセットアップ
  
  分散トレーシングとメトリクスの設定を行います
  """

  require Logger

  @doc """
  OpenTelemetry を初期化する
  """
  def init do
    # OpenTelemetry の設定
    config = %{
      traces: %{
        processors: [
          {
            :otel_batch_processor,
            %{
              exporter: {:opentelemetry_exporter, %{
                endpoints: [
                  {:http, Application.get_env(:opentelemetry, :otlp_endpoint, "http://localhost:4318"), []}
                ]
              }}
            }
          }
        ],
        sampler: {:parent_based, %{
          root: {:trace_id_ratio_based, Application.get_env(:opentelemetry, :sampling_ratio, 1.0)}
        }}
      }
    }

    # アプリケーション固有のテレメトリイベントを設定
    attach_telemetry_handlers()

    Logger.info("OpenTelemetry initialized with config: #{inspect(config)}")
  end

  @doc """
  テレメトリハンドラーをアタッチする
  """
  def attach_telemetry_handlers do
    # Phoenix
    :telemetry.attach_many(
      "phoenix-instrumentation",
      [
        [:phoenix, :endpoint, :start],
        [:phoenix, :endpoint, :stop],
        [:phoenix, :router_dispatch, :start],
        [:phoenix, :router_dispatch, :stop]
      ],
      &handle_phoenix_event/4,
      nil
    )

    # Ecto
    :telemetry.attach_many(
      "ecto-instrumentation",
      [
        [:ecto, :query]
      ],
      &handle_ecto_event/4,
      nil
    )

    # Absinthe (GraphQL)
    :telemetry.attach_many(
      "absinthe-instrumentation",
      [
        [:absinthe, :execute, :operation, :start],
        [:absinthe, :execute, :operation, :stop],
        [:absinthe, :resolve, :field, :start],
        [:absinthe, :resolve, :field, :stop]
      ],
      &handle_absinthe_event/4,
      nil
    )

    # カスタムイベント
    :telemetry.attach_many(
      "custom-instrumentation",
      [
        [:cqrs, :command, :start],
        [:cqrs, :command, :stop],
        [:cqrs, :query, :start],
        [:cqrs, :query, :stop],
        [:cqrs, :saga, :start],
        [:cqrs, :saga, :stop],
        [:cqrs, :event, :published],
        [:cqrs, :event_store, :append],
        [:cqrs, :event_store, :read]
      ],
      &handle_custom_event/4,
      nil
    )

    Logger.info("Telemetry handlers attached")
  end

  # Phoenix イベントハンドラー
  defp handle_phoenix_event(event, measurements, metadata, _config) do
    case event do
      [:phoenix, :endpoint, :start] ->
        # HTTPリクエストの開始
        :otel_telemetry.start_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          "HTTP #{metadata.conn.method} #{metadata.conn.request_path}",
          metadata,
          %{kind: :server}
        )

      [:phoenix, :endpoint, :stop] ->
        # HTTPリクエストの終了
        :otel_telemetry.set_current_telemetry_span(:opentelemetry.get_tracer(__MODULE__), metadata)
        :otel_telemetry.end_telemetry_span(metadata)

      _ ->
        :ok
    end
  end

  # Ecto イベントハンドラー
  defp handle_ecto_event([:ecto, :query], measurements, metadata, _config) do
    total_time = System.convert_time_unit(measurements.total_time, :native, :millisecond)
    
    :otel_telemetry.with_span(
      :opentelemetry.get_tracer(__MODULE__),
      "db.query",
      %{
        "db.system" => "postgresql",
        "db.statement" => metadata.query,
        "db.repo" => inspect(metadata.repo),
        "db.total_time_ms" => total_time
      },
      fn ->
        :ok
      end
    )
  end

  # Absinthe イベントハンドラー
  defp handle_absinthe_event(event, measurements, metadata, _config) do
    case event do
      [:absinthe, :execute, :operation, :start] ->
        :otel_telemetry.start_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          "GraphQL #{metadata.options.operation_name || "Anonymous"}",
          metadata,
          %{kind: :internal}
        )

      [:absinthe, :execute, :operation, :stop] ->
        :otel_telemetry.set_current_telemetry_span(:opentelemetry.get_tracer(__MODULE__), metadata)
        :otel_telemetry.end_telemetry_span(metadata)

      [:absinthe, :resolve, :field, :start] ->
        field_name = metadata.resolution.path |> Enum.join(".")
        :otel_telemetry.start_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          "GraphQL.resolve #{field_name}",
          metadata,
          %{kind: :internal}
        )

      [:absinthe, :resolve, :field, :stop] ->
        :otel_telemetry.set_current_telemetry_span(:opentelemetry.get_tracer(__MODULE__), metadata)
        :otel_telemetry.end_telemetry_span(metadata)

      _ ->
        :ok
    end
  end

  # カスタムイベントハンドラー
  defp handle_custom_event(event, measurements, metadata, _config) do
    span_name = case event do
      [:cqrs, :command, _] -> "Command #{metadata[:command_type] || "Unknown"}"
      [:cqrs, :query, _] -> "Query #{metadata[:query_type] || "Unknown"}"
      [:cqrs, :saga, _] -> "Saga #{metadata[:saga_type] || "Unknown"}"
      [:cqrs, :event, :published] -> "Event Published #{metadata[:event_type] || "Unknown"}"
      [:cqrs, :event_store, :append] -> "EventStore Append"
      [:cqrs, :event_store, :read] -> "EventStore Read"
      _ -> "Unknown Event"
    end

    case List.last(event) do
      :start ->
        :otel_telemetry.start_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          span_name,
          metadata,
          %{kind: :internal}
        )

      :stop ->
        :otel_telemetry.set_current_telemetry_span(:opentelemetry.get_tracer(__MODULE__), metadata)
        :otel_telemetry.end_telemetry_span(metadata)

      :published ->
        :otel_telemetry.with_span(
          :opentelemetry.get_tracer(__MODULE__),
          span_name,
          metadata,
          fn -> :ok end
        )

      _ ->
        :ok
    end
  end
end