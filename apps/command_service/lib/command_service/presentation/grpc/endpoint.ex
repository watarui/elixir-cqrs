defmodule CommandService.Presentation.Grpc.Endpoint do
  @moduledoc """
  Command Service の gRPC エンドポイント
  """

  use GRPC.Endpoint

  intercept(GRPC.Server.Interceptors.Logger)

  # gRPC サーバーの登録
  run([
    CommandService.Presentation.Grpc.CategoryServer,
    CommandService.Presentation.Grpc.ProductServer
  ])
end
