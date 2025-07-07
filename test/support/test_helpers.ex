defmodule ElixirCqrs.TestHelpers do
  @moduledoc """
  Common test helpers for CQRS testing.
  """

  alias ElixirCqrs.Factory

  @doc """
  Sets up the test database for CommandService.
  """
  def setup_command_db(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(CommandService.Infrastructure.Database.Repo)
    :ok
  end

  @doc """
  Sets up the test database for QueryService.
  """
  def setup_query_db(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(QueryService.Infrastructure.Database.Repo)
    :ok
  end

  @doc """
  Sets up both databases for integration tests.
  """
  def setup_all_dbs(context) do
    setup_command_db(context)
    setup_query_db(context)
    :ok
  end

  @doc """
  Creates a product through the command service and waits for projection.
  """
  def create_product_with_projection(attrs \\ %{}) do
    product = Factory.build(:product, attrs)
    command = Factory.build(:create_product_command, payload: product)

    {:ok, event} = CommandService.Application.CommandBus.dispatch(command)

    # Wait for projection to be updated
    wait_for_projection(fn ->
      QueryService.Infrastructure.Repositories.ProductRepository.get(product.id)
    end)

    product
  end

  @doc """
  Creates a category through the command service and waits for projection.
  """
  def create_category_with_projection(attrs \\ %{}) do
    category = Factory.build(:category, attrs)
    command = Factory.build(:create_category_command, payload: category)

    {:ok, event} = CommandService.Application.CommandBus.dispatch(command)

    # Wait for projection to be updated
    wait_for_projection(fn ->
      QueryService.Infrastructure.Repositories.CategoryRepository.get(category.id)
    end)

    category
  end

  @doc """
  Waits for a projection to be available, with timeout.
  """
  def wait_for_projection(check_fn, timeout \\ 5000) do
    start_time = System.monotonic_time(:millisecond)

    Stream.interval(100)
    |> Stream.take_while(fn _ ->
      System.monotonic_time(:millisecond) - start_time < timeout
    end)
    |> Enum.reduce_while(nil, fn _, _ ->
      case check_fn.() do
        {:ok, result} -> {:halt, {:ok, result}}
        _ -> {:cont, nil}
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      _ -> {:error, :timeout}
    end
  end

  @doc """
  Asserts that an event was published to the event store.
  """
  def assert_event_published(event_type, aggregate_id) do
    events = CommandService.Infrastructure.EventStore.PostgresEventStore.get_events(aggregate_id)

    assert Enum.any?(events, fn event ->
      event.event_type == event_type
    end), "Expected event #{event_type} for aggregate #{aggregate_id} was not published"
  end

  @doc """
  Asserts that a command was handled successfully.
  """
  def assert_command_success({:ok, event}) do
    assert event != nil
    assert event.event_id != nil
    event
  end

  def assert_command_success(result) do
    flunk("Expected {:ok, event} but got #{inspect(result)}")
  end

  @doc """
  Asserts that a command failed with expected error.
  """
  def assert_command_failure({:error, reason}, expected_reason) do
    assert reason == expected_reason
  end

  def assert_command_failure(result, _expected_reason) do
    flunk("Expected {:error, reason} but got #{inspect(result)}")
  end

  @doc """
  Creates a GraphQL context for testing.
  """
  def graphql_context(user_id \\ nil) do
    %{
      current_user: user_id && %{id: user_id},
      loader: Dataloader.new()
    }
  end

  @doc """
  Executes a GraphQL query and returns the result.
  """
  def execute_graphql(query, variables \\ %{}, context \\ %{}) do
    Absinthe.run(query, ClientService.GraphQL.Schema,
      variables: variables,
      context: context
    )
  end

  @doc """
  Asserts GraphQL query success.
  """
  def assert_graphql_success({:ok, %{data: data}}) when data != nil do
    data
  end

  def assert_graphql_success(result) do
    flunk("Expected successful GraphQL result but got #{inspect(result)}")
  end

  @doc """
  Asserts GraphQL query has errors.
  """
  def assert_graphql_error({:ok, %{errors: errors}}) when errors != [] do
    errors
  end

  def assert_graphql_error(result) do
    flunk("Expected GraphQL errors but got #{inspect(result)}")
  end

  @doc """
  Cleans up test data by aggregate ID.
  """
  def cleanup_aggregate(aggregate_id) do
    # This would typically clean up events and projections
    # Implementation depends on your cleanup strategy
    :ok
  end

  @doc """
  Generates a unique ID for testing.
  """
  def generate_id, do: UUID.uuid4()

  @doc """
  Creates test metadata.
  """
  def test_metadata(user_id \\ nil) do
    %{
      user_id: user_id || generate_id(),
      timestamp: DateTime.utc_now(),
      test_run: true
    }
  end
end
