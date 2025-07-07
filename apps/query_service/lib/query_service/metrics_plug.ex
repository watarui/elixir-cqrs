defmodule QueryService.MetricsPlug do
  @moduledoc """
  Prometheusメトリクスを公開するためのHTTPエンドポイント
  """

  use Plug.Router

  plug :match
  plug :dispatch

  get "/metrics" do
    metrics_data = TelemetryMetricsPrometheus.Core.scrape()
    
    conn
    |> put_resp_content_type("text/plain; version=0.0.4")
    |> send_resp(200, metrics_data)
  end

  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "ok", service: "query-service"}))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end