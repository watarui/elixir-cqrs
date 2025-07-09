defmodule QueryService.Presentation.Grpc.CategoryQueryServer do
  @moduledoc """
  カテゴリクエリの gRPC サーバー実装
  """

  use GRPC.Server, service: ElixirCqrs.CategoryQueryService.Service

  alias QueryService.Domain.Models.Category
  alias ElixirCqrs.Common.{Error, Timestamp}

  require Logger

  @doc """
  カテゴリを取得
  """
  def get_category(request, _stream) do
    Logger.info("Getting category: #{request.id}")

    # TODO: リポジトリから取得
    # 仮実装
    case request.id do
      "not-found" ->
        %{
          category: nil,
          error: Error.new("NOT_FOUND", "Category not found")
        }
      id ->
        %{
          category: %{
            id: id,
            name: "Sample Category",
            product_count: 0,
            created_at: Timestamp.from_datetime(DateTime.utc_now()),
            updated_at: Timestamp.from_datetime(DateTime.utc_now())
          },
          error: nil
        }
    end
  end

  @doc """
  カテゴリ一覧を取得
  """
  def list_categories(request, _stream) do
    Logger.info("Listing categories")

    # TODO: リポジトリから取得
    # 仮実装
    categories = [
      %{
        id: "1",
        name: "電化製品",
        product_count: 10,
        created_at: Timestamp.from_datetime(DateTime.utc_now()),
        updated_at: Timestamp.from_datetime(DateTime.utc_now())
      },
      %{
        id: "2",
        name: "書籍",
        product_count: 5,
        created_at: Timestamp.from_datetime(DateTime.utc_now()),
        updated_at: Timestamp.from_datetime(DateTime.utc_now())
      }
    ]

    %{
      categories: categories,
      total_count: length(categories),
      error: nil
    }
  end

  @doc """
  カテゴリを検索
  """
  def search_categories(request, _stream) do
    Logger.info("Searching categories: #{request.search_term}")

    # TODO: リポジトリから検索
    # 仮実装
    %{
      categories: [],
      total_count: 0,
      error: nil
    }
  end
end