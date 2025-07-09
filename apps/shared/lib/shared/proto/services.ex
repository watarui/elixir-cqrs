defmodule ElixirCqrs.CategoryCommandService.Service do
  @moduledoc """
  カテゴリコマンドサービスの定義
  """
  use GRPC.Service, name: "elixir_cqrs.CategoryCommandService"

  rpc(:CreateCategory, stream(false), stream(false))
  rpc(:UpdateCategory, stream(false), stream(false))
  rpc(:DeleteCategory, stream(false), stream(false))
end

defmodule ElixirCqrs.ProductCommandService.Service do
  @moduledoc """
  商品コマンドサービスの定義
  """
  use GRPC.Service, name: "elixir_cqrs.ProductCommandService"

  rpc(:CreateProduct, stream(false), stream(false))
  rpc(:UpdateProduct, stream(false), stream(false))
  rpc(:ChangeProductPrice, stream(false), stream(false))
  rpc(:DeleteProduct, stream(false), stream(false))
end

defmodule ElixirCqrs.CategoryQueryService.Service do
  @moduledoc """
  カテゴリクエリサービスの定義
  """
  use GRPC.Service, name: "elixir_cqrs.CategoryQueryService"

  rpc(:GetCategory, stream(false), stream(false))
  rpc(:ListCategories, stream(false), stream(false))
  rpc(:SearchCategories, stream(false), stream(false))
end

defmodule ElixirCqrs.ProductQueryService.Service do
  @moduledoc """
  商品クエリサービスの定義
  """
  use GRPC.Service, name: "elixir_cqrs.ProductQueryService"

  rpc(:GetProduct, stream(false), stream(false))
  rpc(:ListProducts, stream(false), stream(false))
  rpc(:SearchProducts, stream(false), stream(false))
end
