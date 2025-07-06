defmodule ClientService.Router do
  @moduledoc """
  GraphQL ルーター - API エンドポイントの定義
  """

  use Phoenix.Router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  # GraphQL エンドポイント
  scope "/api" do
    pipe_through(:api)

    forward("/graphql", Absinthe.Plug,
      schema: ClientService.GraphQL.Schema,
      context: %{pubsub: ClientService.PubSub}
    )

    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: ClientService.GraphQL.Schema,
      context: %{pubsub: ClientService.PubSub},
      interface: :simple
    )
  end

  # 健全性チェック
  scope "/" do
    pipe_through(:api)

    get("/health", ClientService.HealthController, :check)
  end
end
