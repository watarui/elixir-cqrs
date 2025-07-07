# GraphQL APIテストスクリプト
Mix.install([
  {:httpoison, "~> 1.8"},
  {:jason, "~> 1.2"}
])

# GraphQL エンドポイント
graphql_endpoint = "http://localhost:4000/api/graphql"

# ヘルパー関数
defmodule GraphQLTester do
  def query(query_string, variables \\ %{}, endpoint) do
    body =
      Jason.encode!(%{
        query: query_string,
        variables: variables
      })

    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    case HTTPoison.post(endpoint, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Jason.decode!(response_body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: error_body}} ->
        %{"errors" => [%{"message" => "HTTP #{status_code}: #{error_body}"}]}

      {:error, %HTTPoison.Error{reason: reason}} ->
        %{"errors" => [%{"message" => "Network error: #{reason}"}]}
    end
  end

  def print_result(result) do
    case result do
      %{"data" => data} when not is_nil(data) ->
        IO.puts("✅ 成功:")
        IO.puts("#{Jason.encode!(data, pretty: true)}")

      %{"errors" => errors} ->
        IO.puts("❌ エラー:")

        Enum.each(errors, fn error ->
          IO.puts("  - #{error["message"]}")
        end)

      _ ->
        IO.puts("❓ 不明なレスポンス:")
        IO.puts("#{Jason.encode!(result, pretty: true)}")
    end
  end
end

IO.puts("🚀 GraphQL APIテスト開始...\n")

# 1. カテゴリ一覧取得
IO.puts("1️⃣ カテゴリ一覧取得:")

categories_query = """
query {
  categories {
    id
    name
    createdAt
    updatedAt
  }
}
"""

categories_result = GraphQLTester.query(categories_query, %{}, graphql_endpoint)
GraphQLTester.print_result(categories_result)

# 2. 商品一覧取得
IO.puts("\n2️⃣ 商品一覧取得:")

products_query = """
query {
  products {
    id
    name
    price
    categoryId
    createdAt
    updatedAt
  }
}
"""

products_result = GraphQLTester.query(products_query, %{}, graphql_endpoint)
GraphQLTester.print_result(products_result)

IO.puts("\n🎯 GraphQL APIテスト完了!")
