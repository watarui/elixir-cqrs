defmodule Shared.Telemetry.Tracing.MessagePropagator do
  @moduledoc """
  メッセージングシステムでのトレース伝播

  Phoenix PubSub やイベントバスでトレースコンテキストを伝播します。
  """

  alias Shared.Telemetry.Tracing.{Propagator, SpanBuilder}

  @doc """
  メッセージ送信時にトレースコンテキストを注入する
  """
  def wrap_publish(topic, message, opts \\ []) do
    metadata = Propagator.inject_to_metadata(Map.get(message, :metadata, %{}))

    # スパンを作成
    {span_name, span_opts} =
      SpanBuilder.messaging_span(
        "publish",
        topic,
        message_id: Map.get(message, :id),
        conversation_id: Map.get(message, :correlation_id),
        attributes: Map.get(opts, :attributes, %{})
      )

    OpenTelemetry.Tracer.with_span(span_name, span_opts, fn ->
      # メタデータを更新したメッセージを返す
      updated_message = Map.put(message, :metadata, metadata)
      {:ok, updated_message}
    end)
  end

  @doc """
  メッセージ受信時にトレースコンテキストを抽出して処理する
  """
  def wrap_consume(message, handler, opts \\ []) do
    metadata = Map.get(message, :metadata, %{})

    case Propagator.extract_from_metadata(metadata) do
      {:ok, context} ->
        # 親コンテキストから継続
        topic = Keyword.get(opts, :topic, "unknown")

        {span_name, span_opts} =
          SpanBuilder.messaging_span(
            "consume",
            topic,
            message_id: Map.get(message, :id),
            conversation_id: Map.get(message, :correlation_id),
            attributes: Map.get(opts, :attributes, %{})
          )

        Propagator.with_extracted_context(
          context,
          span_name,
          span_opts,
          fn -> handler.(message) end
        )

      {:error, _} ->
        # 新しいトレースを開始
        topic = Keyword.get(opts, :topic, "unknown")

        {span_name, span_opts} =
          SpanBuilder.messaging_span(
            "consume",
            topic,
            message_id: Map.get(message, :id),
            conversation_id: Map.get(message, :correlation_id),
            attributes: Map.get(opts, :attributes, %{})
          )

        OpenTelemetry.Tracer.with_span(span_name, span_opts, fn ->
          handler.(message)
        end)
    end
  end

  @doc """
  イベントバス用のラッパー
  """
  def wrap_event_publish(event, opts \\ []) do
    event_type = event.__struct__ |> Module.split() |> List.last()
    topic = Keyword.get(opts, :topic, "events")

    {span_name, span_opts} =
      SpanBuilder.event_span(
        event,
        :publish,
        attributes: %{
          "event_bus.topic" => topic,
          "event_bus.partition_key" => get_partition_key(event)
        }
      )

    OpenTelemetry.Tracer.with_span(span_name, span_opts, fn ->
      # メタデータにトレースコンテキストを注入
      metadata = Map.get(event, :metadata, %{})
      updated_metadata = Propagator.inject_to_metadata(metadata)
      updated_event = Map.put(event, :metadata, updated_metadata)

      {:ok, updated_event}
    end)
  end

  @doc """
  イベントハンドラー用のラッパー
  """
  def wrap_event_handler(event, handler, opts \\ []) do
    metadata = Map.get(event, :metadata, %{})

    case Propagator.extract_from_metadata(metadata) do
      {:ok, context} ->
        {span_name, span_opts} =
          SpanBuilder.event_span(
            event,
            :handle,
            attributes: Map.get(opts, :attributes, %{})
          )

        Propagator.with_extracted_context(
          context,
          span_name,
          span_opts,
          fn -> handler.(event) end
        )

      {:error, _} ->
        {span_name, span_opts} =
          SpanBuilder.event_span(
            event,
            :handle,
            attributes: Map.get(opts, :attributes, %{})
          )

        OpenTelemetry.Tracer.with_span(span_name, span_opts, fn ->
          handler.(event)
        end)
    end
  end

  @doc """
  コマンドバス用のラッパー
  """
  def wrap_command_dispatch(command, handler, opts \\ []) do
    {span_name, span_opts} =
      SpanBuilder.command_span(
        command,
        attributes: Map.get(opts, :attributes, %{})
      )

    OpenTelemetry.Tracer.with_span(span_name, span_opts, fn ->
      # コマンドメタデータにトレースコンテキストを保存
      ctx = OpenTelemetry.Ctx.get_current()

      case OpenTelemetry.Tracer.current_span_ctx(ctx) do
        :undefined ->
          handler.(command)

        span_ctx ->
          trace_id =
            span_ctx
            |> elem(0)
            |> elem(0)
            |> Integer.to_string(16)
            |> String.downcase()
            |> String.pad_leading(32, "0")

          # トレース ID をコマンドのコンテキストに追加
          command_with_trace =
            if Map.has_key?(command, :metadata) do
              metadata = Map.put(command.metadata, :trace_id, trace_id)
              Map.put(command, :metadata, metadata)
            else
              command
            end

          handler.(command_with_trace)
      end
    end)
  end

  @doc """
  クエリバス用のラッパー
  """
  def wrap_query_dispatch(query, handler, opts \\ []) do
    {span_name, span_opts} =
      SpanBuilder.query_span(
        query,
        attributes: Map.get(opts, :attributes, %{})
      )

    OpenTelemetry.Tracer.with_span(span_name, span_opts, fn ->
      handler.(query)
    end)
  end

  @doc """
  Saga 実行用のラッパー
  """
  def wrap_saga_step(saga_id, saga_type, step_name, handler, opts \\ []) do
    correlation_id = Keyword.get(opts, :correlation_id)

    {span_name, span_opts} =
      SpanBuilder.saga_span(
        saga_id,
        saga_type,
        step_name,
        correlation_id: correlation_id,
        attributes: Map.get(opts, :attributes, %{})
      )

    OpenTelemetry.Tracer.with_span(span_name, span_opts, fn ->
      handler.()
    end)
  end

  # プライベート関数

  defp get_partition_key(event) do
    cond do
      Map.has_key?(event, :aggregate_id) -> event.aggregate_id
      Map.has_key?(event, :id) -> event.id
      true -> nil
    end
  end
end
