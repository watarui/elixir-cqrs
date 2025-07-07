defmodule ClientService.MetricsController do
  @moduledoc """
  Prometheusメトリクスエンドポイント
  """
  
  use Phoenix.Controller
  
  def metrics(conn, _params) do
    metrics = TelemetryMetricsPrometheus.Core.scrape()
    
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end
end