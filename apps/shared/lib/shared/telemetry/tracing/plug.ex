defmodule Shared.Telemetry.Tracing.Plug do
  @moduledoc """
  Phoenix Plug for OpenTelemetry トレーシング

  HTTPリクエストに対してトレースコンテキストの抽出と注入を行います。
  """

  import Plug.Conn
  alias Shared.Telemetry.Tracing.{Propagator, SpanBuilder}

  require Logger

  @behaviour Plug

  @trace_id_header "x-trace-id"
  @request_id_header "x-request-id"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    # リクエストからトレースコンテキストを抽出
    headers = get_request_headers(conn)

    case Propagator.extract_from_headers(headers) do
      {:ok, context} ->
        # 既存のトレースコンテキストがある場合
        Propagator.with_extracted_context(
          context,
          "HTTP #{conn.method} #{conn.request_path}",
          build_span_opts(conn),
          fn ->
            process_request(conn)
          end
        )

      {:error, _} ->
        # 新しいトレースを開始
        OpenTelemetry.Tracer.with_span(
          "HTTP #{conn.method} #{conn.request_path}",
          build_span_opts(conn),
          fn ->
            process_request(conn)
          end
        )
    end
  end

  defp process_request(conn) do
    # トレース ID をレスポンスヘッダーに追加
    conn
    |> put_trace_headers()
    |> register_before_send(&add_response_attributes/1)
  end

  defp get_request_headers(conn) do
    conn.req_headers
  end

  defp build_span_opts(conn) do
    {_, span_opts} =
      SpanBuilder.http_span(
        conn.method,
        conn.request_path,
        url: get_request_url(conn),
        target: conn.request_path <> get_query_string(conn),
        host: conn.host,
        scheme: to_string(conn.scheme),
        user_agent: get_header(conn, "user-agent")
      )

    # リクエスト属性を追加
    attributes =
      Map.merge(span_opts[:attributes], %{
        "http.client_ip" => get_client_ip(conn),
        "http.request_content_length" => get_header(conn, "content-length"),
        "http.request_content_type" => get_header(conn, "content-type"),
        "net.host.name" => conn.host,
        "net.host.port" => conn.port
      })

    Keyword.put(span_opts, :attributes, attributes)
  end

  defp put_trace_headers(conn) do
    ctx = OpenTelemetry.Ctx.get_current()

    case OpenTelemetry.Tracer.current_span_ctx(ctx) do
      :undefined ->
        conn

      span_ctx ->
        trace_id =
          span_ctx
          |> elem(0)
          |> elem(0)
          |> Integer.to_string(16)
          |> String.downcase()
          |> String.pad_leading(32, "0")

        conn
        |> put_resp_header(@trace_id_header, trace_id)
        |> put_resp_header(@request_id_header, conn.assigns[:request_id] || trace_id)
    end
  end

  defp add_response_attributes(conn) do
    ctx = OpenTelemetry.Ctx.get_current()

    case OpenTelemetry.Tracer.current_span_ctx(ctx) do
      :undefined ->
        :ok

      span_ctx ->
        # レスポンス属性を追加
        attributes = %{
          "http.status_code" => conn.status,
          "http.response_content_length" => get_resp_header_value(conn, "content-length"),
          "http.response_content_type" => get_resp_header_value(conn, "content-type")
        }

        :otel_span.set_attributes(span_ctx, attributes)

        # エラーステータスの場合
        if conn.status >= 400 do
          :otel_span.set_status(span_ctx, :error, "HTTP #{conn.status}")
        end
    end

    conn
  end

  defp get_request_url(conn) do
    scheme = to_string(conn.scheme)
    host = conn.host
    port = get_port_string(conn)
    path = conn.request_path
    query = get_query_string(conn)

    "#{scheme}://#{host}#{port}#{path}#{query}"
  end

  defp get_port_string(conn) do
    default_ports = %{"http" => 80, "https" => 443}
    scheme = to_string(conn.scheme)

    if conn.port == default_ports[scheme] do
      ""
    else
      ":#{conn.port}"
    end
  end

  defp get_query_string(conn) do
    case conn.query_string do
      "" -> ""
      query -> "?#{query}"
    end
  end

  defp get_client_ip(conn) do
    forwarded_for = get_header(conn, "x-forwarded-for")

    if forwarded_for do
      # 最初のIPアドレスを取得
      forwarded_for
      |> String.split(",")
      |> List.first()
      |> String.trim()
    else
      # 直接接続のIPアドレス
      conn.remote_ip
      |> :inet.ntoa()
      |> to_string()
    end
  end

  defp get_header(conn, header) do
    case get_req_header(conn, header) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp get_resp_header_value(conn, header) do
    case get_resp_header(conn, header) do
      [value | _] -> value
      [] -> nil
    end
  end
end
