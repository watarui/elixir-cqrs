defmodule Proto.Error do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:type, 1, type: :string)
  field(:message, 2, type: :string)
end
