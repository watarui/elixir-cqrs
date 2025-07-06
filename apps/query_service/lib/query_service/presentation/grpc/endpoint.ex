defmodule QueryService.Presentation.Grpc.Endpoint do
  @moduledoc """
  Query Service gRPC Endpoint
  """

  use GRPC.Endpoint

  run(QueryService.Presentation.Grpc.CategoryQueryServer)
  run(QueryService.Presentation.Grpc.ProductQueryServer)
end
