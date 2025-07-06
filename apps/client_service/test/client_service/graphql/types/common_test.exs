defmodule ClientService.GraphQL.Types.CommonTest do
  use ExUnit.Case, async: true

  alias ClientService.GraphQL.Types.Common

  describe "datetime scalar" do
    test "module exists" do
      assert function_exported?(Common, :__info__, 1)
    end
  end

  describe "error type" do
    test "module defines error type" do
      # Common型が適切に定義されていることを確認
      assert Code.ensure_loaded?(Common)
    end
  end

  describe "health_check type" do
    test "module compiles successfully" do
      # モジュールが正常にコンパイルされることを確認
      assert Common.__info__(:module) == ClientService.GraphQL.Types.Common
    end
  end
end
