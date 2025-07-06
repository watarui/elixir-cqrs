defmodule ClientService.Endpoint do
  @moduledoc """
  Phoenix エンドポイント - HTTP サーバーとGraphQL API
  """

  use Phoenix.Endpoint, otp_app: :client_service

  # GraphQL および WebSocket サポート
  socket("/socket", ClientService.UserSocket,
    websocket: true,
    longpoll: false
  )

  # 静的ファイル（GraphQL Playground用）
  plug(Plug.Static,
    at: "/",
    from: :client_service,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)
  )

  # CORS設定
  plug(Corsica,
    origins: ["http://localhost:3000", "http://localhost:4000"],
    allow_headers: ["accept", "authorization", "content-type", "origin"],
    allow_credentials: true
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(Plug.Session,
    store: :cookie,
    key: "_client_service_key",
    signing_salt: "client_service_salt",
    same_site: "Lax"
  )

  # GraphQL エンドポイント
  plug(ClientService.Router)
end
