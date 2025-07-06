defmodule ClientServiceTest do
  use ExUnit.Case

  test "application module exists" do
    assert Code.ensure_loaded?(ClientService.Application)
  end

  test "endpoint module exists" do
    assert Code.ensure_loaded?(ClientService.Endpoint)
  end
end
