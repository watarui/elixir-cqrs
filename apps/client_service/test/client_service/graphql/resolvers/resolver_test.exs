defmodule ClientService.GraphQL.Resolvers.ResolverTest do
  use ExUnit.Case, async: true

  alias ClientService.GraphQL.Resolvers.CategoryResolver
  alias ClientService.GraphQL.Resolvers.ProductResolver

  describe "CategoryResolver" do
    test "module exists" do
      assert Code.ensure_loaded?(CategoryResolver)
    end

    test "compiles successfully" do
      assert Code.ensure_loaded?(CategoryResolver)
    end

    test "module compiles successfully" do
      assert CategoryResolver.__info__(:module) ==
               ClientService.GraphQL.Resolvers.CategoryResolver
    end
  end

  describe "ProductResolver" do
    test "module exists" do
      assert Code.ensure_loaded?(ProductResolver)
    end

    test "compiles successfully" do
      assert Code.ensure_loaded?(ProductResolver)
    end

    test "module compiles successfully" do
      assert ProductResolver.__info__(:module) == ClientService.GraphQL.Resolvers.ProductResolver
    end
  end
end
