defmodule ClientService.Endpoint do
  @moduledoc """
  Phoenix エンドポイント - HTTP サーバー
  """

  use Phoenix.Endpoint, otp_app: :client_service

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  # 最低限のプラグインのみを使用
  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # 基本的なルーター
  plug(ClientService.Router)
end
