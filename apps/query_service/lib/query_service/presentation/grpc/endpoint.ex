defmodule QueryService.Presentation.Grpc.Endpoint do
  @moduledoc """
  Query Service の gRPC エンドポイント
  """

  use GRPC.Endpoint

  intercept(GRPC.Server.Interceptors.Logger)

  # gRPC サーバーの登録
  run([
    QueryService.Presentation.Grpc.CategoryQueryServer,
    QueryService.Presentation.Grpc.ProductQueryServer
  ])
end
