defmodule Proto.Category do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
end

defmodule Proto.Product do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:price, 3, type: :int32)
  field(:category, 4, proto3_optional: true, type: Proto.Category)
end
