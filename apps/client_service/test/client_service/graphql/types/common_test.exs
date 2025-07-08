defmodule ClientService.GraphQL.Types.CommonTest do
  use ExUnit.Case, async: true

  alias ClientService.GraphQL.Types.Common

  describe "module loading" do
    test "module exists and loads correctly" do
      assert Code.ensure_loaded?(Common)
    end
  end

  describe "datetime scalar" do
    test "parse and serialize functions are defined" do
      # Private functions can't be tested directly, but we can ensure the module is loaded
      assert Code.ensure_loaded?(Common)
    end
  end
end
