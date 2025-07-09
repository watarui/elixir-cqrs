defmodule ClientServiceWeb.Router do
  use ClientServiceWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ClientServiceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # GraphQL エンドポイント
  scope "/" do
    pipe_through :api

    forward "/graphql", Absinthe.Plug,
      schema: ClientService.GraphQL.Schema

    forward "/graphiql", Absinthe.Plug.GraphiQL,
      schema: ClientService.GraphQL.Schema,
      interface: :playground
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:client_service, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ClientServiceWeb.Telemetry
    end
  end
end