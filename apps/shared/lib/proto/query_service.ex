defmodule Query.CategoryQuery.Service do
  @moduledoc """
  Category Query gRPC Service Definition
  """

  use GRPC.Service, name: "query.CategoryQuery", protoc_gen_elixir_version: "0.14.1"

  rpc(:GetCategory, Query.CategoryQueryRequest, Query.CategoryQueryResponse)
  rpc(:GetCategoryByName, Query.CategoryByNameRequest, Query.CategoryQueryResponse)
  rpc(:ListCategories, Query.Empty, Query.CategoryListResponse)
  rpc(:SearchCategories, Query.CategorySearchRequest, Query.CategoryListResponse)
  rpc(:ListCategoriesPaginated, Query.CategoryPaginationRequest, Query.CategoryListResponse)
  rpc(:GetCategoryStatistics, Query.Empty, Query.CategoryStatisticsResponse)
  rpc(:CategoryExists, Query.CategoryExistsRequest, Query.CategoryExistsResponse)
end

defmodule Query.ProductQuery.Service do
  @moduledoc """
  Product Query gRPC Service Definition
  """

  use GRPC.Service, name: "query.ProductQuery", protoc_gen_elixir_version: "0.14.1"

  rpc(:GetProduct, Query.ProductQueryRequest, Query.ProductQueryResponse)
  rpc(:GetProductByName, Query.ProductByNameRequest, Query.ProductQueryResponse)
  rpc(:ListProducts, Query.Empty, Query.ProductListResponse)
  rpc(:GetProductsByCategory, Query.ProductByCategoryRequest, Query.ProductListResponse)
  rpc(:SearchProducts, Query.ProductSearchRequest, Query.ProductListResponse)
  rpc(:GetProductsByPriceRange, Query.ProductPriceRangeRequest, Query.ProductListResponse)
  rpc(:ListProductsPaginated, Query.ProductPaginationRequest, Query.ProductListResponse)
  rpc(:GetProductStatistics, Query.Empty, Query.ProductStatisticsResponse)
  rpc(:ProductExists, Query.ProductExistsRequest, Query.ProductExistsResponse)
end

defmodule Query.CategoryQuery.Stub do
  @moduledoc """
  Category Query gRPC Client Stub
  """
  use GRPC.Stub, service: Query.CategoryQuery.Service
end

defmodule Query.ProductQuery.Stub do
  @moduledoc """
  Product Query gRPC Client Stub
  """
  use GRPC.Stub, service: Query.ProductQuery.Service
end
