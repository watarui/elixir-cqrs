defmodule CommandService.Presentation.Grpc.Endpoint do
  @moduledoc """
  Command Service gRPC Endpoint
  """

  use GRPC.Endpoint

  run(CommandService.Presentation.Grpc.CategoryCommandServer)
  run(CommandService.Presentation.Grpc.ProductCommandServer)
  run(CommandService.Presentation.Grpc.SagaCommandServer)
end
