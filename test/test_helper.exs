{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.start()

# Ensure all apps are started for integration tests
{:ok, _} = Application.ensure_all_started(:shared)
{:ok, _} = Application.ensure_all_started(:command_service)
{:ok, _} = Application.ensure_all_started(:query_service)
{:ok, _} = Application.ensure_all_started(:client_service)

# Setup Ecto sandboxes for test isolation
Ecto.Adapters.SQL.Sandbox.mode(CommandService.Infrastructure.Database.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(QueryService.Infrastructure.Database.Repo, :manual)
