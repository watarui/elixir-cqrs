# Test helper設定をロード  
Code.require_file("../../../test/support/factory.ex", __DIR__)
Code.require_file("../../../test/support/test_helpers.ex", __DIR__)
Code.require_file("../../../test/support/graphql_helpers.ex", __DIR__)

# Ecto Sandboxの設定（両方のRepoに対して）
Ecto.Adapters.SQL.Sandbox.mode(CommandService.Infrastructure.Database.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(QueryService.Infrastructure.Database.Repo, :manual)

# Moxの設定（使用する場合）
# Mox.defmock(ClientService.CQRSFacadeMock, for: ClientService.Application.CQRSFacade)

ExUnit.start()

# Moxを設定するが、実際のinterfaceが存在しないため、コメントアウト
# Mox.defmock(ClientService.GrpcConnectionsMock, for: ClientService.Infrastructure.GrpcConnections)
# Mox.defmock(ClientService.CategoryQueryMock, for: Query.CategoryQuery.Stub)
# Mox.defmock(ClientService.ProductQueryMock, for: Query.ProductQuery.Stub)
# Mox.defmock(ClientService.CategoryCommandMock, for: Proto.CategoryCommand.Stub)
# Mox.defmock(ClientService.ProductCommandMock, for: Proto.ProductCommand.Stub)
