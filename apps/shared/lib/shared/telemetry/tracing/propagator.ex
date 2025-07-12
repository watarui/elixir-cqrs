defmodule Shared.Telemetry.Tracing.Propagator do
  @moduledoc """
  トレースコンテキストの伝播

  分散システム間でトレース情報を伝播するための機能を提供します。
  """

  require Logger

  @trace_header "traceparent"
  @trace_state_header "tracestate"
  @baggage_header "baggage"
  @b3_trace_id_header "x-b3-traceid"
  @b3_span_id_header "x-b3-spanid"
  @b3_sampled_header "x-b3-sampled"

  @doc """
  HTTPヘッダーからトレースコンテキストを抽出する
  """
  def extract_from_headers(headers) when is_list(headers) do
    headers_map = Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end)

    with {:ok, trace_context} <- extract_trace_context(headers_map),
         {:ok, baggage} <- extract_baggage(headers_map) do
      {:ok,
       %{
         trace_context: trace_context,
         baggage: baggage
       }}
    end
  end

  @doc """
  トレースコンテキストをHTTPヘッダーに注入する
  """
  def inject_to_headers(headers \\ []) do
    ctx = OpenTelemetry.Ctx.get_current()

    case OpenTelemetry.Tracer.current_span_ctx(ctx) do
      :undefined ->
        headers

      span_ctx ->
        headers
        |> inject_trace_context(span_ctx)
        |> inject_baggage(ctx)
        |> inject_b3_headers(span_ctx)
    end
  end

  @doc """
  メッセージメタデータからトレースコンテキストを抽出する
  """
  def extract_from_metadata(metadata) when is_map(metadata) do
    with {:ok, trace_id} <- Map.fetch(metadata, :trace_id),
         {:ok, span_id} <- Map.fetch(metadata, :span_id),
         {:ok, trace_flags} <- Map.fetch(metadata, :trace_flags) do
      {:ok,
       %{
         trace_id: trace_id,
         span_id: span_id,
         trace_flags: trace_flags,
         trace_state: Map.get(metadata, :trace_state, ""),
         baggage: Map.get(metadata, :baggage, %{})
       }}
    else
      _ -> {:error, :missing_trace_context}
    end
  end

  @doc """
  トレースコンテキストをメッセージメタデータに注入する
  """
  def inject_to_metadata(metadata \\ %{}) do
    ctx = OpenTelemetry.Ctx.get_current()

    case OpenTelemetry.Tracer.current_span_ctx(ctx) do
      :undefined ->
        metadata

      span_ctx ->
        trace_id = span_ctx |> :otel_span.trace_id() |> :otel_id_binary.encode()
        span_id = span_ctx |> :otel_span.span_id() |> :otel_id_binary.encode()
        trace_flags = span_ctx |> :otel_span.trace_flags()

        metadata
        |> Map.put(:trace_id, trace_id)
        |> Map.put(:span_id, span_id)
        |> Map.put(:trace_flags, trace_flags)
        |> Map.put(:trace_state, :otel_span.trace_state(span_ctx))
        |> Map.put(:baggage, :otel_baggage.get_all(ctx))
    end
  end

  @doc """
  新しいスパンを開始してコンテキストを設定する
  """
  def with_extracted_context(context, span_name, opts \\ [], fun) do
    parent_ctx = build_parent_context(context)

    OpenTelemetry.Ctx.with_ctx(parent_ctx, fn ->
      OpenTelemetry.Tracer.with_span(span_name, opts, fun)
    end)
  end

  # プライベート関数

  defp extract_trace_context(headers) do
    case headers[@trace_header] do
      nil ->
        # B3 形式も試す
        extract_b3_context(headers)

      traceparent ->
        parse_traceparent(traceparent, headers[@trace_state_header])
    end
  end

  defp parse_traceparent(traceparent, tracestate) do
    # W3C Trace Context 形式: version-trace_id-span_id-trace_flags
    case String.split(traceparent, "-") do
      ["00", trace_id, span_id, trace_flags] ->
        with {:ok, trace_id_binary} <- Base.decode16(trace_id, case: :lower),
             {:ok, span_id_binary} <- Base.decode16(span_id, case: :lower),
             {flags, _} <- Integer.parse(trace_flags, 16) do
          {:ok,
           %{
             trace_id: trace_id_binary,
             span_id: span_id_binary,
             trace_flags: flags,
             trace_state: tracestate || ""
           }}
        else
          _ -> {:error, :invalid_traceparent}
        end

      _ ->
        {:error, :invalid_traceparent_format}
    end
  end

  defp extract_b3_context(headers) do
    with {:ok, trace_id} <- get_b3_trace_id(headers),
         {:ok, span_id} <- get_b3_span_id(headers),
         sampled <- get_b3_sampled(headers) do
      {:ok,
       %{
         trace_id: trace_id,
         span_id: span_id,
         trace_flags: if(sampled, do: 1, else: 0),
         trace_state: ""
       }}
    end
  end

  defp get_b3_trace_id(headers) do
    case headers[@b3_trace_id_header] do
      nil -> {:error, :missing_b3_trace_id}
      trace_id -> Base.decode16(trace_id, case: :lower)
    end
  end

  defp get_b3_span_id(headers) do
    case headers[@b3_span_id_header] do
      nil -> {:error, :missing_b3_span_id}
      span_id -> Base.decode16(span_id, case: :lower)
    end
  end

  defp get_b3_sampled(headers) do
    case headers[@b3_sampled_header] do
      "1" -> true
      "0" -> false
      _ -> false
    end
  end

  defp extract_baggage(headers) do
    case headers[@baggage_header] do
      nil ->
        {:ok, %{}}

      baggage_string ->
        baggage =
          baggage_string
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&parse_baggage_entry/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.into(%{})

        {:ok, baggage}
    end
  end

  defp parse_baggage_entry(entry) do
    case String.split(entry, "=", parts: 2) do
      [key, value] -> {key, URI.decode(value)}
      _ -> nil
    end
  end

  defp inject_trace_context(headers, span_ctx) do
    trace_id = span_ctx |> :otel_span.trace_id() |> :otel_id_binary.encode()
    span_id = span_ctx |> :otel_span.span_id() |> :otel_id_binary.encode()
    trace_flags = span_ctx |> :otel_span.trace_flags()

    traceparent =
      "00-#{trace_id}-#{span_id}-#{String.pad_leading(Integer.to_string(trace_flags, 16), 2, "0")}"

    headers
    |> Keyword.put(@trace_header, traceparent)
    |> inject_trace_state(span_ctx)
  end

  defp inject_trace_state(headers, span_ctx) do
    case :otel_span.trace_state(span_ctx) do
      "" -> headers
      trace_state -> Keyword.put(headers, @trace_state_header, trace_state)
    end
  end

  defp inject_baggage(headers, ctx) do
    case :otel_baggage.get_all(ctx) do
      [] ->
        headers

      baggage ->
        baggage_string =
          baggage
          |> Enum.map_join(",", fn {k, v} -> "#{k}=#{URI.encode(v)}" end)

        Keyword.put(headers, @baggage_header, baggage_string)
    end
  end

  defp inject_b3_headers(headers, span_ctx) do
    trace_id = span_ctx |> :otel_span.trace_id() |> :otel_id_binary.encode()
    span_id = span_ctx |> :otel_span.span_id() |> :otel_id_binary.encode()
    sampled = if(:otel_span.trace_flags(span_ctx) == 1, do: "1", else: "0")

    headers
    |> Keyword.put(@b3_trace_id_header, trace_id)
    |> Keyword.put(@b3_span_id_header, span_id)
    |> Keyword.put(@b3_sampled_header, sampled)
  end

  defp build_parent_context(context) do
    span_ctx =
      :otel_span_ctx.new(
        context.trace_context.trace_id,
        context.trace_context.span_id,
        context.trace_context.trace_flags,
        context.trace_context.trace_state
      )

    ctx = OpenTelemetry.Ctx.new()
    ctx = OpenTelemetry.Tracer.set_current_span(ctx, span_ctx)

    # Baggage を設定
    Enum.reduce(context.baggage, ctx, fn {k, v}, acc ->
      :otel_baggage.set(acc, k, v)
    end)
  end
end
