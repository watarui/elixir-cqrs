defmodule ClientService.Router do
  @moduledoc """
  基本的なルーター - ヘルスチェック用とGraphQL API
  """

  use Phoenix.Router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # 健全性チェック
  scope "/" do
    pipe_through(:api)

    get("/health", ClientService.HealthController, :check)
  end

  # GraphQL API
  scope "/graphql" do
    pipe_through(:api)

    post("/", Absinthe.Plug, schema: ClientService.GraphQL.Schema)
  end
end
