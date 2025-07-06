ExUnit.start()

# Moxを設定するが、実際のinterfaceが存在しないため、コメントアウト
# Mox.defmock(ClientService.GrpcConnectionsMock, for: ClientService.Infrastructure.GrpcConnections)
# Mox.defmock(ClientService.CategoryQueryMock, for: Query.CategoryQuery.Stub)
# Mox.defmock(ClientService.ProductQueryMock, for: Query.ProductQuery.Stub)
# Mox.defmock(ClientService.CategoryCommandMock, for: Proto.CategoryCommand.Stub)
# Mox.defmock(ClientService.ProductCommandMock, for: Proto.ProductCommand.Stub)
