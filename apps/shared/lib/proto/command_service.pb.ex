defmodule ElixirCqrs.CreateCategoryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:name, 1, type: :string)
  field(:description, 2, type: :string)
  field(:parent_id, 3, type: :string, json_name: "parentId")
  field(:metadata, 4, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.CreateCategoryResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:category, 2, type: ElixirCqrs.Category)
end

defmodule ElixirCqrs.UpdateCategoryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:parent_id, 4, type: :string, json_name: "parentId")
  field(:metadata, 5, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.UpdateCategoryResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:category, 1, type: ElixirCqrs.Category)
end

defmodule ElixirCqrs.DeleteCategoryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:metadata, 2, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.DeleteCategoryResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:success, 1, type: :bool)
end

defmodule ElixirCqrs.CreateProductRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:name, 1, type: :string)
  field(:description, 2, type: :string)
  field(:category_id, 3, type: :string, json_name: "categoryId")
  field(:price, 4, type: ElixirCqrs.Money)
  field(:initial_stock, 5, type: :int32, json_name: "initialStock")
  field(:metadata, 6, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.CreateProductResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:product, 2, type: ElixirCqrs.Product)
end

defmodule ElixirCqrs.UpdateProductRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:category_id, 4, type: :string, json_name: "categoryId")
  field(:price, 5, type: ElixirCqrs.Money)
  field(:metadata, 6, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.UpdateProductResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:product, 1, type: ElixirCqrs.Product)
end

defmodule ElixirCqrs.DeleteProductRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:metadata, 2, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.DeleteProductResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:success, 1, type: :bool)
end

defmodule ElixirCqrs.UpdateStockRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:product_id, 1, type: :string, json_name: "productId")
  field(:quantity, 2, type: :int32)
  field(:metadata, 3, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.UpdateStockResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:current_stock, 1, type: :int32, json_name: "currentStock")
end

defmodule ElixirCqrs.ReserveStockRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:product_id, 1, type: :string, json_name: "productId")
  field(:quantity, 2, type: :int32)
  field(:reservation_id, 3, type: :string, json_name: "reservationId")
  field(:metadata, 4, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.ReserveStockResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:success, 1, type: :bool)
  field(:remaining_stock, 2, type: :int32, json_name: "remainingStock")
end

defmodule ElixirCqrs.ReleaseStockRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:product_id, 1, type: :string, json_name: "productId")
  field(:quantity, 2, type: :int32)
  field(:reservation_id, 3, type: :string, json_name: "reservationId")
  field(:metadata, 4, type: ElixirCqrs.Metadata)
end

defmodule ElixirCqrs.ReleaseStockResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:success, 1, type: :bool)
  field(:current_stock, 2, type: :int32, json_name: "currentStock")
end

defmodule ElixirCqrs.CategoryCommandService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "elixir_cqrs.CategoryCommandService",
    protoc_gen_elixir_version: "0.14.1"

  rpc(:CreateCategory, ElixirCqrs.CreateCategoryRequest, ElixirCqrs.CreateCategoryResponse)

  rpc(:UpdateCategory, ElixirCqrs.UpdateCategoryRequest, ElixirCqrs.UpdateCategoryResponse)

  rpc(:DeleteCategory, ElixirCqrs.DeleteCategoryRequest, ElixirCqrs.DeleteCategoryResponse)
end

defmodule ElixirCqrs.CategoryCommandService.Stub do
  @moduledoc false

  use GRPC.Stub, service: ElixirCqrs.CategoryCommandService.Service
end

defmodule ElixirCqrs.ProductCommandService.Service do
  @moduledoc false

  use GRPC.Service, name: "elixir_cqrs.ProductCommandService", protoc_gen_elixir_version: "0.14.1"

  rpc(:CreateProduct, ElixirCqrs.CreateProductRequest, ElixirCqrs.CreateProductResponse)

  rpc(:UpdateProduct, ElixirCqrs.UpdateProductRequest, ElixirCqrs.UpdateProductResponse)

  rpc(:DeleteProduct, ElixirCqrs.DeleteProductRequest, ElixirCqrs.DeleteProductResponse)

  rpc(:UpdateStock, ElixirCqrs.UpdateStockRequest, ElixirCqrs.UpdateStockResponse)

  rpc(:ReserveStock, ElixirCqrs.ReserveStockRequest, ElixirCqrs.ReserveStockResponse)

  rpc(:ReleaseStock, ElixirCqrs.ReleaseStockRequest, ElixirCqrs.ReleaseStockResponse)
end

defmodule ElixirCqrs.ProductCommandService.Stub do
  @moduledoc false

  use GRPC.Stub, service: ElixirCqrs.ProductCommandService.Service
end
