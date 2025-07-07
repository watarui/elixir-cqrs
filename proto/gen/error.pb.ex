defmodule Proto.Error.DetailsEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Proto.Error do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :type, 1, type: :string
  field :message, 2, type: :string
  field :code, 3, type: :int32
  field :details, 4, repeated: true, type: Proto.Error.DetailsEntry, map: true
end
