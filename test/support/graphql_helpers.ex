defmodule ElixirCqrs.GraphQLHelpers do
  @moduledoc """
  Test helpers for GraphQL testing.
  """

  import ExUnit.Assertions

  @doc """
  Builds a GraphQL query document.
  """
  def query(query_string) do
    """
    query {
      #{query_string}
    }
    """
  end

  @doc """
  Builds a GraphQL mutation document.
  """
  def mutation(mutation_string) do
    """
    mutation {
      #{mutation_string}
    }
    """
  end

  @doc """
  Builds a parameterized GraphQL query.
  """
  def parameterized_query(name, params, query_string) do
    params_string = format_params(params)
    """
    query #{name}(#{params_string}) {
      #{query_string}
    }
    """
  end

  @doc """
  Builds a parameterized GraphQL mutation.
  """
  def parameterized_mutation(name, params, mutation_string) do
    params_string = format_params(params)
    """
    mutation #{name}(#{params_string}) {
      #{mutation_string}
    }
    """
  end

  defp format_params(params) do
    params
    |> Enum.map(fn {name, type} -> "$#{name}: #{type}" end)
    |> Enum.join(", ")
  end

  @doc """
  Executes a GraphQL query against the schema.
  """
  def run_query(query, variables \\ %{}, context \\ %{}) do
    Absinthe.run(query, ClientService.GraphQL.Schema,
      variables: variables,
      context: context
    )
  end

  @doc """
  Asserts that a GraphQL response contains no errors.
  """
  def assert_no_errors({:ok, result}) do
    refute Map.has_key?(result, :errors), 
           "Expected no errors but got: #{inspect(Map.get(result, :errors))}"
    result.data
  end

  @doc """
  Asserts that a GraphQL response contains specific errors.
  """
  def assert_has_error({:ok, result}, expected_message) do
    assert Map.has_key?(result, :errors), "Expected errors but got none"
    
    messages = Enum.map(result.errors, & &1.message)
    assert expected_message in messages,
           "Expected error message '#{expected_message}' not found in: #{inspect(messages)}"
    
    result.errors
  end

  @doc """
  Extracts data from a successful GraphQL response.
  """
  def get_data({:ok, %{data: data}}, path) when is_list(path) do
    get_in(data, path)
  end

  def get_data({:ok, %{data: data}}, path) when is_binary(path) do
    get_in(data, [path])
  end

  @doc """
  Common GraphQL queries for testing.
  """
  def list_products_query do
    query("""
      products {
        id
        name
        description
        price
        category {
          id
          name
        }
      }
    """)
  end

  def get_product_query do
    parameterized_query("GetProduct", [id: "ID!"], """
      product(id: $id) {
        id
        name
        description
        price
        category {
          id
          name
        }
      }
    """)
  end

  def create_product_mutation do
    parameterized_mutation("CreateProduct", [input: "CreateProductInput!"], """
      createProduct(input: $input) {
        id
        name
        description
        price
        categoryId
      }
    """)
  end

  def update_product_mutation do
    parameterized_mutation("UpdateProduct", [id: "ID!", input: "UpdateProductInput!"], """
      updateProduct(id: $id, input: $input) {
        id
        name
        description
        price
        categoryId
      }
    """)
  end

  def delete_product_mutation do
    parameterized_mutation("DeleteProduct", [id: "ID!"], """
      deleteProduct(id: $id) {
        success
        message
      }
    """)
  end

  def list_categories_query do
    query("""
      categories {
        id
        name
        description
        parentId
        path
        children {
          id
          name
        }
      }
    """)
  end

  def create_order_mutation do
    parameterized_mutation("CreateOrder", [input: "CreateOrderInput!"], """
      createOrder(input: $input) {
        id
        customerId
        items {
          productId
          quantity
          unitPrice
        }
        totalAmount
        status
      }
    """)
  end

  @doc """
  Helper to build complex GraphQL fragments.
  """
  def fragment(name, type, fields) do
    """
    fragment #{name} on #{type} {
      #{fields}
    }
    """
  end

  @doc """
  Asserts specific field values in GraphQL response.
  """
  def assert_field_equals(data, field_path, expected_value) do
    actual = get_in(data, List.wrap(field_path))
    assert actual == expected_value,
           "Expected #{inspect(field_path)} to be #{inspect(expected_value)}, got #{inspect(actual)}"
  end

  @doc """
  Creates a test context with authentication.
  """
  def authenticated_context(user_id) do
    %{
      current_user: %{id: user_id},
      auth_token: "test_token_#{user_id}"
    }
  end
end