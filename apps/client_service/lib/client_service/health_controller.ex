defmodule ClientService.HealthController do
  @moduledoc """
  健全性チェック用コントローラー
  """

  use Phoenix.Controller, formats: [:json]
  alias ClientService.Infrastructure.GrpcConnections

  @doc """
  健全性チェックエンドポイント
  """
  def check(conn, _params) do
    health_status = get_health_status()

    case health_status.status do
      "healthy" ->
        conn
        |> put_status(200)
        |> json(health_status)

      "degraded" ->
        conn
        |> put_status(200)
        |> json(health_status)

      "unhealthy" ->
        conn
        |> put_status(503)
        |> json(health_status)
    end
  end

  # プライベート関数

  defp get_health_status do
    services = check_dependent_services()
    overall_status = determine_overall_status(services)

    %{
      status: overall_status,
      version: ClientService.version(),
      timestamp: DateTime.utc_now(),
      services: services
    }
  end

  defp check_dependent_services do
    connection_status = GrpcConnections.get_connection_status()

    [
      check_command_service(connection_status.command),
      check_query_service(connection_status.query)
    ]
  end

  defp check_command_service(connection_status) do
    start_time = System.monotonic_time(:millisecond)

    status =
      case connection_status do
        :connected -> "healthy"
        :disconnected -> "unhealthy"
        _ -> "unhealthy"
      end

    response_time = System.monotonic_time(:millisecond) - start_time

    %{
      name: "command-service",
      status: status,
      response_time: response_time,
      last_checked: DateTime.utc_now()
    }
  end

  defp check_query_service(connection_status) do
    start_time = System.monotonic_time(:millisecond)

    status =
      case connection_status do
        :connected -> "healthy"
        :disconnected -> "unhealthy"
        _ -> "unhealthy"
      end

    response_time = System.monotonic_time(:millisecond) - start_time

    %{
      name: "query-service",
      status: status,
      response_time: response_time,
      last_checked: DateTime.utc_now()
    }
  end

  defp determine_overall_status(services) do
    healthy_count =
      services
      |> Enum.count(fn service -> service.status == "healthy" end)

    total_count = length(services)

    cond do
      healthy_count == total_count -> "healthy"
      healthy_count > 0 -> "degraded"
      true -> "unhealthy"
    end
  end
end
