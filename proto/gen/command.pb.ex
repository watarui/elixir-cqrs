defmodule Proto.CRUD do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :UNKNOWN, 0
  field :INSERT, 1
  field :UPDATE, 2
  field :DELETE, 3
end

defmodule Proto.CategoryUpParam do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :crud, 1, type: Proto.CRUD, enum: true
  field :id, 2, type: :string
  field :name, 3, type: :string
end

defmodule Proto.ProductUpParam do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :crud, 1, type: Proto.CRUD, enum: true
  field :id, 2, type: :string
  field :name, 3, type: :string
  field :price, 4, type: :double
  field :categoryId, 5, type: :string
end

defmodule Proto.CategoryUpResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :category, 1, type: Proto.Category
  field :error, 2, type: Proto.Error
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule Proto.ProductUpResult do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :product, 1, type: Proto.Product
  field :error, 2, type: Proto.Error
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end
