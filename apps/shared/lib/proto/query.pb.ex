defmodule Query.Category do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:created_at, 3, type: :int64, json_name: "createdAt")
  field(:updated_at, 4, type: :int64, json_name: "updatedAt")
end

defmodule Query.Product do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:price, 3, type: :double)
  field(:category_id, 4, type: :string, json_name: "categoryId")
  field(:category, 5, type: Query.Category)
  field(:created_at, 6, type: :int64, json_name: "createdAt")
  field(:updated_at, 7, type: :int64, json_name: "updatedAt")
end

defmodule Query.CategoryQueryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
end

defmodule Query.CategoryByNameRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:name, 1, type: :string)
end

defmodule Query.CategorySearchRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:search_term, 1, type: :string, json_name: "searchTerm")
end

defmodule Query.CategoryPaginationRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:page, 1, type: :int32)
  field(:per_page, 2, type: :int32, json_name: "perPage")
end

defmodule Query.CategoryIdsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:ids, 1, repeated: true, type: :string)
end

defmodule Query.CategoryExistsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
end

defmodule Query.ProductQueryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
end

defmodule Query.ProductByNameRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:name, 1, type: :string)
end

defmodule Query.ProductSearchRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:search_term, 1, type: :string, json_name: "searchTerm")
end

defmodule Query.ProductByCategoryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:category_id, 1, type: :string, json_name: "categoryId")
end

defmodule Query.ProductPriceRangeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:min_price, 1, type: :double, json_name: "minPrice")
  field(:max_price, 2, type: :double, json_name: "maxPrice")
end

defmodule Query.ProductSortRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:sort_order, 1, type: :string, json_name: "sortOrder")
end

defmodule Query.ProductPaginationRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:page, 1, type: :int32)
  field(:per_page, 2, type: :int32, json_name: "perPage")
end

defmodule Query.ProductIdsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:ids, 1, repeated: true, type: :string)
end

defmodule Query.ProductExistsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
end

defmodule Query.ProductAdvancedSearchRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:name, 1, type: :string)
  field(:category_id, 2, type: :string, json_name: "categoryId")
  field(:min_price, 3, type: :double, json_name: "minPrice")
  field(:max_price, 4, type: :double, json_name: "maxPrice")
  field(:sort_by, 5, type: :string, json_name: "sortBy")
  field(:sort_order, 6, type: :string, json_name: "sortOrder")
  field(:limit, 7, type: :int32)
  field(:offset, 8, type: :int32)
end

defmodule Query.CategoryProductStatisticsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:category_id, 1, type: :string, json_name: "categoryId")
end

defmodule Query.CategoryQueryResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:category, 1, type: Query.Category)
end

defmodule Query.CategoryListResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:categories, 1, repeated: true, type: Query.Category)
end

defmodule Query.CategoryStatisticsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:total_count, 1, type: :int32, json_name: "totalCount")
  field(:has_categories, 2, type: :bool, json_name: "hasCategories")
  field(:categories_with_timestamps, 3, type: :int32, json_name: "categoriesWithTimestamps")
end

defmodule Query.CategoryExistsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:exists, 1, type: :bool)
end

defmodule Query.ProductQueryResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:product, 1, type: Query.Product)
end

defmodule Query.ProductListResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:products, 1, repeated: true, type: Query.Product)
end

defmodule Query.ProductStatisticsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:total_count, 1, type: :int32, json_name: "totalCount")
  field(:has_products, 2, type: :bool, json_name: "hasProducts")
  field(:average_price, 3, type: :double, json_name: "averagePrice")
  field(:min_price, 4, type: :double, json_name: "minPrice")
  field(:max_price, 5, type: :double, json_name: "maxPrice")
  field(:products_with_timestamps, 6, type: :int32, json_name: "productsWithTimestamps")
end

defmodule Query.ProductExistsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:exists, 1, type: :bool)
end

defmodule Query.CategoryProductStatisticsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:category_id, 1, type: :string, json_name: "categoryId")
  field(:total_count, 2, type: :int32, json_name: "totalCount")
  field(:has_products, 3, type: :bool, json_name: "hasProducts")
  field(:average_price, 4, type: :double, json_name: "averagePrice")
  field(:min_price, 5, type: :double, json_name: "minPrice")
  field(:max_price, 6, type: :double, json_name: "maxPrice")
end

defmodule Query.Empty do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3
end
