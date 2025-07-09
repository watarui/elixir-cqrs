defmodule CommandService.Presentation.Grpc.ProductServer do
  @moduledoc """
  商品コマンドの gRPC サーバー実装
  """

  use GRPC.Server, service: ElixirCqrs.ProductCommandService.Service

  alias CommandService.Domain.Aggregates.ProductAggregate
  alias Shared.Infrastructure.EventStore.EventStore
  alias ElixirCqrs.Common.{Result, Error}

  require Logger

  @doc """
  商品を作成
  """
  def create_product(request, _stream) do
    Logger.info("Creating product: #{request.name}")

    # 価格を数値に変換
    with {price, ""} <- Float.parse(request.price),
         {:ok, aggregate} <- ProductAggregate.create(request.name, price, request.category_id),
         {:ok, _} <- save_aggregate(aggregate) do
      %{
        result: Result.success("Product created successfully"),
        id: aggregate.id.value
      }
    else
      :error ->
        %{
          result: Result.failure(Error.new("INVALID_PRICE", "Invalid price format")),
          id: ""
        }

      {:error, reason} ->
        %{
          result: Result.failure(Error.new("CREATE_FAILED", reason)),
          id: ""
        }
    end
  end

  @doc """
  商品を更新
  """
  def update_product(request, _stream) do
    Logger.info("Updating product: #{request.id}")

    # 更新パラメータを構築
    params = build_update_params(request)

    with {:ok, aggregate} <- load_aggregate(request.id),
         {:ok, updated_aggregate} <- ProductAggregate.update(aggregate, params),
         {:ok, _} <- save_aggregate(updated_aggregate) do
      %{result: Result.success("Product updated successfully")}
    else
      {:error, :not_found} ->
        %{result: Result.failure(Error.new("NOT_FOUND", "Product not found"))}

      {:error, reason} ->
        %{result: Result.failure(Error.new("UPDATE_FAILED", inspect(reason)))}
    end
  end

  @doc """
  商品価格を変更
  """
  def change_product_price(request, _stream) do
    Logger.info("Changing product price: #{request.id}")

    with {new_price, ""} <- Float.parse(request.new_price),
         {:ok, aggregate} <- load_aggregate(request.id),
         {:ok, updated_aggregate} <- ProductAggregate.change_price(aggregate, new_price),
         {:ok, _} <- save_aggregate(updated_aggregate) do
      %{result: Result.success("Product price changed successfully")}
    else
      :error ->
        %{result: Result.failure(Error.new("INVALID_PRICE", "Invalid price format"))}

      {:error, :not_found} ->
        %{result: Result.failure(Error.new("NOT_FOUND", "Product not found"))}

      {:error, reason} ->
        %{result: Result.failure(Error.new("PRICE_CHANGE_FAILED", inspect(reason)))}
    end
  end

  @doc """
  商品を削除
  """
  def delete_product(request, _stream) do
    Logger.info("Deleting product: #{request.id}")

    with {:ok, aggregate} <- load_aggregate(request.id),
         {:ok, deleted_aggregate} <- ProductAggregate.delete(aggregate),
         {:ok, _} <- save_aggregate(deleted_aggregate) do
      %{result: Result.success("Product deleted successfully")}
    else
      {:error, :not_found} ->
        %{result: Result.failure(Error.new("NOT_FOUND", "Product not found"))}

      {:error, reason} ->
        %{result: Result.failure(Error.new("DELETE_FAILED", inspect(reason)))}
    end
  end

  # Private functions

  defp load_aggregate(id) do
    case EventStore.get_events(id) do
      {:ok, []} ->
        {:error, :not_found}

      {:ok, events} ->
        aggregate = ProductAggregate.rebuild_from_events(events)
        {:ok, aggregate}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp save_aggregate(aggregate) do
    {_cleared_aggregate, events} = ProductAggregate.get_and_clear_uncommitted_events(aggregate)

    if length(events) > 0 do
      EventStore.append_events(
        aggregate.id.value,
        "product",
        events,
        aggregate.version - length(events),
        %{}
      )
    else
      {:ok, aggregate.version}
    end
  end

  defp build_update_params(request) do
    params = %{}

    params =
      if request.name != nil && request.name != "" do
        Map.put(params, :name, request.name)
      else
        params
      end

    params =
      if request.price != nil && request.price != "" do
        case Float.parse(request.price) do
          {price, ""} -> Map.put(params, :price, price)
          _ -> params
        end
      else
        params
      end

    if request.category_id != nil && request.category_id != "" do
      Map.put(params, :category_id, request.category_id)
    else
      params
    end
  end
end
