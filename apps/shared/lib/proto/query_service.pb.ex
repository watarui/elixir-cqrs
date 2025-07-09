defmodule ElixirCqrs.GetCategoryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
end

defmodule ElixirCqrs.GetCategoryResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:category, 1, type: ElixirCqrs.Category)
end

defmodule ElixirCqrs.ListCategoriesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:pagination, 1, type: ElixirCqrs.Pagination)
  field(:active_only, 2, type: :bool, json_name: "activeOnly")
  field(:parent_id, 3, type: :string, json_name: "parentId")
end

defmodule ElixirCqrs.ListCategoriesResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:categories, 1, repeated: true, type: ElixirCqrs.Category)
  field(:total_count, 2, type: :int32, json_name: "totalCount")
end

defmodule ElixirCqrs.SearchCategoriesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:keyword, 1, type: :string)
  field(:pagination, 2, type: ElixirCqrs.Pagination)
end

defmodule ElixirCqrs.SearchCategoriesResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:categories, 1, repeated: true, type: ElixirCqrs.Category)
  field(:total_count, 2, type: :int32, json_name: "totalCount")
end

defmodule ElixirCqrs.GetProductRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
end

defmodule ElixirCqrs.GetProductResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:product, 1, type: ElixirCqrs.Product)
end

defmodule ElixirCqrs.ListProductsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:pagination, 1, type: ElixirCqrs.Pagination)
  field(:active_only, 2, type: :bool, json_name: "activeOnly")
  field(:category_id, 3, type: :string, json_name: "categoryId")
end

defmodule ElixirCqrs.ListProductsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:products, 1, repeated: true, type: ElixirCqrs.Product)
  field(:total_count, 2, type: :int32, json_name: "totalCount")
end

defmodule ElixirCqrs.SearchProductsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:search_term, 1, type: :string, json_name: "searchTerm")
  field(:pagination, 2, type: ElixirCqrs.Pagination)
  field(:category_id, 3, type: :string, json_name: "categoryId")
  field(:min_price, 4, type: ElixirCqrs.Money, json_name: "minPrice")
  field(:max_price, 5, type: ElixirCqrs.Money, json_name: "maxPrice")
end

defmodule ElixirCqrs.SearchProductsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:products, 1, repeated: true, type: ElixirCqrs.Product)
  field(:total_count, 2, type: :int32, json_name: "totalCount")
end

defmodule ElixirCqrs.GetProductsByCategoryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:category_id, 1, type: :string, json_name: "categoryId")
  field(:pagination, 2, type: ElixirCqrs.Pagination)
  field(:active_only, 3, type: :bool, json_name: "activeOnly")
end

defmodule ElixirCqrs.GetProductsByCategoryResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:products, 1, repeated: true, type: ElixirCqrs.Product)
  field(:total_count, 2, type: :int32, json_name: "totalCount")
  field(:category, 3, type: ElixirCqrs.Category)
end

defmodule ElixirCqrs.CategoryQueryService.Service do
  @moduledoc false

  use GRPC.Service, name: "elixir_cqrs.CategoryQueryService", protoc_gen_elixir_version: "0.14.1"

  rpc(:GetCategory, ElixirCqrs.GetCategoryRequest, ElixirCqrs.GetCategoryResponse)

  rpc(:ListCategories, ElixirCqrs.ListCategoriesRequest, ElixirCqrs.ListCategoriesResponse)

  rpc(:SearchCategories, ElixirCqrs.SearchCategoriesRequest, ElixirCqrs.SearchCategoriesResponse)
end

defmodule ElixirCqrs.CategoryQueryService.Stub do
  @moduledoc false

  use GRPC.Stub, service: ElixirCqrs.CategoryQueryService.Service
end

defmodule ElixirCqrs.ProductQueryService.Service do
  @moduledoc false

  use GRPC.Service, name: "elixir_cqrs.ProductQueryService", protoc_gen_elixir_version: "0.14.1"

  rpc(:GetProduct, ElixirCqrs.GetProductRequest, ElixirCqrs.GetProductResponse)

  rpc(:ListProducts, ElixirCqrs.ListProductsRequest, ElixirCqrs.ListProductsResponse)

  rpc(:SearchProducts, ElixirCqrs.SearchProductsRequest, ElixirCqrs.SearchProductsResponse)

  rpc(
    :GetProductsByCategory,
    ElixirCqrs.GetProductsByCategoryRequest,
    ElixirCqrs.GetProductsByCategoryResponse
  )
end

defmodule ElixirCqrs.ProductQueryService.Stub do
  @moduledoc false

  use GRPC.Stub, service: ElixirCqrs.ProductQueryService.Service
end
