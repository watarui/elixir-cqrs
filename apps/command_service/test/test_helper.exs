# Test helper設定をロード
# Code.require_file("../../../test/support/factory.ex", __DIR__)
# Code.require_file("../../../test/support/test_helpers.ex", __DIR__)
# Code.require_file("../../../test/support/event_store_helpers.ex", __DIR__)

# Ecto Sandboxの設定
Ecto.Adapters.SQL.Sandbox.mode(CommandService.Infrastructure.Database.Repo, :manual)

Application.ensure_all_started(:db_connection)
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:shared)
Application.ensure_all_started(:command_service)

ExUnit.start()
