{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.start()

# Ensure all apps are started for integration tests
{:ok, _} = Application.ensure_all_started(:shared)
{:ok, _} = Application.ensure_all_started(:command_service)
{:ok, _} = Application.ensure_all_started(:query_service)
{:ok, _} = Application.ensure_all_started(:client_service)

alias CommandService.Infrastructure.Database.Repo, as: CommandRepo
alias Ecto.Adapters.SQL.Sandbox
alias QueryService.Infrastructure.Database.Repo, as: QueryRepo

# Setup Ecto sandboxes for test isolation
Sandbox.mode(CommandRepo, :manual)
Sandbox.mode(QueryRepo, :manual)

# Setup Shared repo if it exists
if Code.ensure_loaded?(Shared.Infrastructure.Database.Repo) do
  Sandbox.mode(Shared.Infrastructure.Database.Repo, :manual)
end

# Start EventStore if needed
if Code.ensure_loaded?(Shared.Infrastructure.EventStore.PostgresAdapter) do
  {:ok, _} = Shared.Infrastructure.EventStore.PostgresAdapter.start_link([])
end
