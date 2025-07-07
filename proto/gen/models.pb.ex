defmodule Proto.Category do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :created_at, 3, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 4, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
end

defmodule Proto.Product do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :price, 3, type: :int32
  field :category, 4, proto3_optional: true, type: Proto.Category
  field :created_at, 5, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 6, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
end
