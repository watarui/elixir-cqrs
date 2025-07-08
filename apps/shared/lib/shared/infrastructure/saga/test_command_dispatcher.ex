defmodule Shared.Infrastructure.Saga.TestCommandDispatcher do
  @moduledoc """
  Test implementation of command dispatcher for saga tests
  """

  def dispatch(command) do
    # In tests, we just return success for any command
    {:ok, %{id: command[:saga_id] || UUID.uuid4()}}
  end

  def dispatch_parallel(commands) do
    results = Enum.map(commands, &dispatch/1)
    {:ok, results}
  end

  def dispatch_compensation(command) do
    # In tests, compensations always succeed
    {:ok, %{compensated: true}}
  end
end
