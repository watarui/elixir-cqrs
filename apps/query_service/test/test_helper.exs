# Test helper設定をロード
Code.require_file("../../../test/support/factory.ex", __DIR__)
Code.require_file("../../../test/support/test_helpers.ex", __DIR__)
Code.require_file("../../../test/support/event_store_helpers.ex", __DIR__)

# Ecto Sandboxの設定
Ecto.Adapters.SQL.Sandbox.mode(QueryService.Infrastructure.Database.Repo, :manual)

ExUnit.start()
