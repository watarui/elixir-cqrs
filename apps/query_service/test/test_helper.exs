# Test helper設定をロード
Code.require_file("../../../test/support/factory.ex", __DIR__)
Code.require_file("../../../test/support/test_helpers.ex", __DIR__)
Code.require_file("../../../test/support/event_store_helpers.ex", __DIR__)

alias Ecto.Adapters.SQL.Sandbox
alias QueryService.Infrastructure.Database.Repo

# Ecto Sandboxの設定
Sandbox.mode(Repo, :manual)

ExUnit.start()
