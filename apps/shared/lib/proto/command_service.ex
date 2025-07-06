defmodule Proto.CategoryCommand.Service do
  @moduledoc """
  Category Command gRPC Service Definition
  """

  use GRPC.Service, name: "proto.CategoryCommand", protoc_gen_elixir_version: "0.14.1"

  rpc(:update_category, Proto.CategoryUpParam, Proto.CategoryUpResult)
end

defmodule Proto.ProductCommand.Service do
  @moduledoc """
  Product Command gRPC Service Definition
  """

  use GRPC.Service, name: "proto.ProductCommand", protoc_gen_elixir_version: "0.14.1"

  rpc(:update_product, Proto.ProductUpParam, Proto.ProductUpResult)
end

defmodule Proto.CategoryCommand.Stub do
  @moduledoc """
  Category Command gRPC Client Stub
  """
  use GRPC.Stub, service: Proto.CategoryCommand.Service
end

defmodule Proto.ProductCommand.Stub do
  @moduledoc """
  Product Command gRPC Client Stub
  """
  use GRPC.Stub, service: Proto.ProductCommand.Service
end
