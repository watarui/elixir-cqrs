defmodule ClientService.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use ExUnit.CaseTemplate

  # Database setup removed to avoid cross-app dependencies
  # alias CommandService.Infrastructure.Database.Repo, as: CommandRepo
  # alias Ecto.Adapters.SQL.Sandbox
  # alias QueryService.Infrastructure.Database.Repo, as: QueryRepo

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

  setup _tags do
    # Database setup removed to avoid cross-app dependencies
    # Original database setup code commented out

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
