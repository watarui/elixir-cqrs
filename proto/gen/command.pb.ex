defmodule Proto.CRUD do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :UNKNOWN, 0
  field :INSERT, 1
  field :UPDATE, 2
  field :DELETE, 3
end

defmodule Proto.CategoryUpParam do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :crud, 1, type: Proto.CRUD, enum: true
  field :id, 2, type: :string
  field :name, 3, type: :string
end

defmodule Proto.ProductUpParam do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :crud, 1, type: Proto.CRUD, enum: true
  field :id, 2, type: :string
  field :name, 3, type: :string
  field :price, 4, type: :double
  field :categoryId, 5, type: :string
end

defmodule Proto.CategoryUpResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :category, 1, type: Proto.Category
  field :error, 2, type: Proto.Error
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule Proto.ProductUpResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :product, 1, type: Proto.Product
  field :error, 2, type: Proto.Error
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule Proto.StartOrderSagaParam do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :orderId, 1, type: :string
  field :customerId, 2, type: :string
  field :items, 3, repeated: true, type: Proto.OrderItem
  field :totalAmount, 4, type: :double
  field :shippingAddress, 5, type: Proto.ShippingAddress
end

defmodule Proto.OrderItem do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :productId, 1, type: :string
  field :productName, 2, type: :string
  field :quantity, 3, type: :int32
  field :unitPrice, 4, type: :double
  field :subtotal, 5, type: :double
end

defmodule Proto.ShippingAddress do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :street, 1, type: :string
  field :city, 2, type: :string
  field :postalCode, 3, type: :string
end

defmodule Proto.StartSagaResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :sagaId, 1, type: :string
  field :status, 2, type: :string
  field :error, 3, type: Proto.Error
  field :startedAt, 4, type: Google.Protobuf.Timestamp
end

defmodule Proto.GetSagaStatusParam do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :sagaId, 1, type: :string
end

defmodule Proto.SagaStatusResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :sagaId, 1, type: :string
  field :state, 2, type: :string
  field :completedSteps, 3, repeated: true, type: :string
  field :currentStep, 4, type: :string
  field :failureReason, 5, type: :string
  field :startedAt, 6, type: Google.Protobuf.Timestamp
  field :completedAt, 7, type: Google.Protobuf.Timestamp
  field :error, 8, type: Proto.Error
end

defmodule Proto.CategoryCommand.Service do
  @moduledoc false

  use GRPC.Service, name: "proto.CategoryCommand", protoc_gen_elixir_version: "0.14.0"

  rpc :Create, Proto.CategoryUpParam, Proto.CategoryUpResult

  rpc :Update, Proto.CategoryUpParam, Proto.CategoryUpResult

  rpc :Delete, Proto.CategoryUpParam, Proto.CategoryUpResult
end

defmodule Proto.CategoryCommand.Stub do
  @moduledoc false

  use GRPC.Stub, service: Proto.CategoryCommand.Service
end

defmodule Proto.ProductCommand.Service do
  @moduledoc false

  use GRPC.Service, name: "proto.ProductCommand", protoc_gen_elixir_version: "0.14.0"

  rpc :Create, Proto.ProductUpParam, Proto.ProductUpResult

  rpc :Update, Proto.ProductUpParam, Proto.ProductUpResult

  rpc :Delete, Proto.ProductUpParam, Proto.ProductUpResult
end

defmodule Proto.ProductCommand.Stub do
  @moduledoc false

  use GRPC.Stub, service: Proto.ProductCommand.Service
end

defmodule Proto.SagaCommand.Service do
  @moduledoc false

  use GRPC.Service, name: "proto.SagaCommand", protoc_gen_elixir_version: "0.14.0"

  rpc :StartOrderSaga, Proto.StartOrderSagaParam, Proto.StartSagaResult

  rpc :GetSagaStatus, Proto.GetSagaStatusParam, Proto.SagaStatusResult
end

defmodule Proto.SagaCommand.Stub do
  @moduledoc false

  use GRPC.Stub, service: Proto.SagaCommand.Service
end
