defmodule QueryService.Infrastructure.Projections.ProductProjection do
  @moduledoc """
  商品プロジェクション

  商品関連のイベントを処理し、Read Model を更新します
  """

  alias QueryService.Infrastructure.Repositories.ProductRepository

  alias Shared.Domain.Events.ProductEvents.{
    ProductCreated,
    ProductUpdated,
    ProductPriceChanged,
    ProductDeleted,
    StockUpdated,
    StockReserved,
    StockReleased
  }

  require Logger

  @doc """
  イベントを処理する
  """
  def handle_event(%{event_type: "ProductCreated", event_data: data}) do
    event = ProductCreated.from_json(data)

    attrs = %{
      id: event.id.value,
      name: event.name.value,
      description: event.description,
      price: Decimal.new(to_string(event.price.amount)),
      currency: event.price.currency,
      stock_quantity: event.stock_quantity,
      category_id: event.category_id.value,
      active: true,
      metadata: %{},
      inserted_at: event.created_at,
      updated_at: event.created_at
    }

    case ProductRepository.create(attrs) do
      {:ok, product} ->
        Logger.info("Product projection created: #{product.id}")
        {:ok, product}

      {:error, reason} ->
        Logger.error("Failed to create product projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%{event_type: "ProductUpdated", event_data: data}) do
    event = ProductUpdated.from_json(data)

    attrs = %{
      name: event.name.value,
      description: event.description,
      category_id: event.category_id.value,
      updated_at: event.updated_at
    }

    case ProductRepository.update(event.id.value, attrs) do
      {:ok, product} ->
        Logger.info("Product projection updated: #{product.id}")
        {:ok, product}

      {:error, reason} ->
        Logger.error("Failed to update product projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%{event_type: "ProductPriceChanged", event_data: data}) do
    event = ProductPriceChanged.from_json(data)

    attrs = %{
      price: Decimal.new(to_string(event.new_price.amount)),
      updated_at: event.changed_at
    }

    case ProductRepository.update(event.id.value, attrs) do
      {:ok, product} ->
        Logger.info("Product price updated: #{product.id}")
        {:ok, product}

      {:error, reason} ->
        Logger.error("Failed to update product price: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%{event_type: "StockUpdated", event_data: data}) do
    event = StockUpdated.from_json(data)

    attrs = %{
      stock_quantity: event.quantity,
      updated_at: event.updated_at
    }

    case ProductRepository.update(event.product_id.value, attrs) do
      {:ok, product} ->
        Logger.info("Product stock updated: #{product.id}")
        {:ok, product}

      {:error, reason} ->
        Logger.error("Failed to update product stock: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(%{event_type: "ProductDeleted", event_data: data}) do
    event = ProductDeleted.from_json(data)

    case ProductRepository.delete(event.id.value) do
      {:ok, _} ->
        Logger.info("Product projection deleted: #{event.id.value}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete product projection: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_event(_event) do
    # 他のイベントは無視
    :ok
  end
end
