defmodule Shared.Telemetry.Setup do
  @moduledoc """
  OpenTelemetry のセットアップ

  分散トレーシングとメトリクスの設定を行います
  """

  require Logger
  alias Shared.Telemetry.Tracing.Config

  @doc """
  OpenTelemetry を初期化する
  """
  def init do
    # 拡張設定を取得
    config = Config.configure_tracer_provider()

    # OpenTelemetry の設定を適用
    apply_opentelemetry_config(config)

    # アプリケーション固有のテレメトリイベントを設定
    attach_telemetry_handlers()

    Logger.info("OpenTelemetry initialized with enhanced configuration")
  end

  defp apply_opentelemetry_config(config) do
    # リソース属性を設定
    :opentelemetry.set_resource(config.resource)

    # プロパゲーターを設定
    :opentelemetry.set_text_map_propagator(
      :opentelemetry_propagator_composite.create(config.propagators)
    )
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
  defp handle_phoenix_event(event, _measurements, metadata, _config) do
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
        :otel_telemetry.set_current_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          metadata
        )

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
  defp handle_absinthe_event(event, _measurements, metadata, _config) do
    case event do
      [:absinthe, :execute, :operation, :start] ->
        :otel_telemetry.start_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          "GraphQL #{metadata.options.operation_name || "Anonymous"}",
          metadata,
          %{kind: :internal}
        )

      [:absinthe, :execute, :operation, :stop] ->
        :otel_telemetry.set_current_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          metadata
        )

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
        :otel_telemetry.set_current_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          metadata
        )

        :otel_telemetry.end_telemetry_span(metadata)

      _ ->
        :ok
    end
  end

  # カスタムイベントハンドラー
  defp handle_custom_event(event, measurements, metadata, _config) do
    span_name =
      case event do
        [:cqrs, :command, _] -> "Command #{metadata[:command_type] || "Unknown"}"
        [:cqrs, :query, _] -> "Query #{metadata[:query_type] || "Unknown"}"
        [:cqrs, :saga, _] -> "Saga #{metadata[:saga_type] || "Unknown"}"
        [:cqrs, :event, :published] -> "Event Published #{metadata[:event_type] || "Unknown"}"
        [:cqrs, :event_store, :append] -> "EventStore Append"
        [:cqrs, :event_store, :read] -> "EventStore Read"
        _ -> "Unknown Event"
      end

    # 追加の属性を構築
    attributes = build_custom_attributes(event, measurements, metadata)

    case List.last(event) do
      :start ->
        :otel_telemetry.start_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          span_name,
          metadata,
          %{kind: :internal, attributes: attributes}
        )

      :stop ->
        :otel_telemetry.set_current_telemetry_span(
          :opentelemetry.get_tracer(__MODULE__),
          metadata
        )

        # 測定値を属性として追加
        if measurements[:duration] do
          :otel_telemetry.add_span_attributes(%{
            "duration_ms" =>
              System.convert_time_unit(measurements.duration, :native, :millisecond)
          })
        end

        :otel_telemetry.end_telemetry_span(metadata)

      :published ->
        :otel_telemetry.with_span(
          :opentelemetry.get_tracer(__MODULE__),
          span_name,
          Map.merge(metadata, %{attributes: attributes}),
          fn -> :ok end
        )

      _ ->
        :ok
    end
  end

  defp build_custom_attributes(event, measurements, metadata) do
    base_attrs = %{
      "event.name" => event |> Enum.join("."),
      "event.timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # イベント固有の属性を追加
    event_attrs =
      case event do
        [:cqrs, :command, _] ->
          %{
            "command.aggregate_id" => metadata[:aggregate_id],
            "command.correlation_id" => metadata[:correlation_id]
          }

        [:cqrs, :saga, _] ->
          %{
            "saga.id" => metadata[:saga_id],
            "saga.correlation_id" => metadata[:correlation_id],
            "saga.current_step" => metadata[:current_step]
          }

        [:cqrs, :event, :published] ->
          %{
            "event.aggregate_id" => metadata[:aggregate_id],
            "event.aggregate_type" => metadata[:aggregate_type],
            "event.version" => metadata[:version]
          }

        _ ->
          %{}
      end

    # 測定値を属性として追加
    measurement_attrs =
      measurements
      |> Enum.map(fn {k, v} -> {"measurement.#{k}", v} end)
      |> Enum.into(%{})

    base_attrs
    |> Map.merge(event_attrs)
    |> Map.merge(measurement_attrs)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
