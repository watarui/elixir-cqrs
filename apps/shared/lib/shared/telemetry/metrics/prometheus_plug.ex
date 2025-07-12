defmodule Shared.Telemetry.Metrics.PrometheusPlug do
  @moduledoc """
  Prometheus メトリクスエンドポイント用の Plug

  /metrics エンドポイントで Prometheus 形式のメトリクスを提供します。
  """

  import Plug.Conn

  alias Shared.Telemetry.Metrics.PrometheusExporter

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    metrics = PrometheusExporter.export()

    conn
    |> put_resp_content_type("text/plain; version=0.0.4")
    |> send_resp(200, metrics)
  end
end
