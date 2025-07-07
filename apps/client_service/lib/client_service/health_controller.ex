defmodule ClientService.HealthController do
  @moduledoc """
  健全性チェック用コントローラー
  """

  use Phoenix.Controller, formats: [:json]

  @doc """
  健全性チェックエンドポイント
  """
  @spec check(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def check(conn, _params) do
    health_status = %{
      status: "healthy",
      version: "0.1.0",
      timestamp: DateTime.utc_now(),
      service: "client_service"
    }

    conn
    |> put_status(200)
    |> json(health_status)
  end
end
