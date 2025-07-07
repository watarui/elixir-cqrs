defmodule Proto.StartOrderSagaParam do
  use Protobuf, syntax: :proto3
  
  field :orderId, 1, type: :string
  field :customerId, 2, type: :string
  field :items, 3, repeated: true, type: Proto.OrderItem
  field :totalAmount, 4, type: :double
  field :shippingAddress, 5, type: Proto.ShippingAddress
end

defmodule Proto.OrderItem do
  use Protobuf, syntax: :proto3
  
  field :productId, 1, type: :string
  field :productName, 2, type: :string
  field :quantity, 3, type: :int32
  field :unitPrice, 4, type: :double
  field :subtotal, 5, type: :double
end

defmodule Proto.ShippingAddress do
  use Protobuf, syntax: :proto3
  
  field :street, 1, type: :string
  field :city, 2, type: :string
  field :postalCode, 3, type: :string
end

defmodule Proto.StartSagaResult do
  use Protobuf, syntax: :proto3
  
  field :sagaId, 1, type: :string
  field :status, 2, type: :string
  field :error, 3, type: Proto.Error
  field :startedAt, 4, type: Google.Protobuf.Timestamp
end

defmodule Proto.GetSagaStatusParam do
  use Protobuf, syntax: :proto3
  
  field :sagaId, 1, type: :string
end

defmodule Proto.SagaStatusResult do
  use Protobuf, syntax: :proto3
  
  field :sagaId, 1, type: :string
  field :state, 2, type: :string
  field :completedSteps, 3, repeated: true, type: :string
  field :currentStep, 4, type: :string
  field :failureReason, 5, type: :string
  field :startedAt, 6, type: Google.Protobuf.Timestamp
  field :completedAt, 7, type: Google.Protobuf.Timestamp
  field :error, 8, type: Proto.Error
end

defmodule Proto.SagaCommand.Service do
  @moduledoc false
  use GRPC.Service, name: "proto.SagaCommand"
  
  rpc :StartOrderSaga, Proto.StartOrderSagaParam, Proto.StartSagaResult
  rpc :GetSagaStatus, Proto.GetSagaStatusParam, Proto.SagaStatusResult
end

defmodule Proto.SagaCommand.Stub do
  @moduledoc false
  use GRPC.Stub, service: Proto.SagaCommand.Service
end