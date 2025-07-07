defmodule ClientService.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  
  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ClientService.ConnCase

      alias ClientService.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint ClientService.Endpoint
    end
  end

  setup tags do
    # Setup database sandbox if needed
    if tags[:async] do
      # For async tests, checkout sandbox
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(CommandService.Infrastructure.Database.Repo)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(QueryService.Infrastructure.Database.Repo)
    else
      # For non-async tests, ensure clean state
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(CommandService.Infrastructure.Database.Repo)
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(QueryService.Infrastructure.Database.Repo)
      
      Ecto.Adapters.SQL.Sandbox.mode(CommandService.Infrastructure.Database.Repo, {:shared, self()})
      Ecto.Adapters.SQL.Sandbox.mode(QueryService.Infrastructure.Database.Repo, {:shared, self()})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end