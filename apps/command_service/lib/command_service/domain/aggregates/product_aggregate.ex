defmodule CommandService.Domain.Aggregates.ProductAggregate do
  @moduledoc """
  商品アグリゲート（イベントソーシング対応）

  商品に関するすべてのビジネスロジックとイベント処理を管理します
  """

  alias CommandService.Domain.ValueObjects.{ProductId, ProductName, ProductPrice, CategoryId}
  alias CommandService.Domain.Logic.{ProductLogic, AggregateLogic}
  alias Shared.Domain.Events.ProductEvents.{
    ProductCreated,
    ProductUpdated,
    ProductDeleted,
    ProductPriceChanged
  }

  defstruct [:id, :name, :price, :category_id, :deleted, :version, :pending_events]

  @type t :: %__MODULE__{
          id: ProductId.t() | nil,
          name: ProductName.t() | nil,
          price: ProductPrice.t() | nil,
          category_id: CategoryId.t() | nil,
          deleted: boolean(),
          version: non_neg_integer(),
          pending_events: list(struct())
        }

  use Shared.Domain.Aggregate.Base
  
  @impl true
  def aggregate_id(%__MODULE__{id: nil}), do: nil
  def aggregate_id(%__MODULE__{id: id}), do: ProductId.value(id)

  # コマンドハンドラー

  @impl true
  def execute(%__MODULE__{deleted: true}, _command) do
    {:error, "Cannot execute commands on deleted product"}
  end

  def execute(%__MODULE__{id: nil}, {:create_product, params}) do
    # 純粋な関数でビジネスルールを検証
    with :ok <- ProductLogic.validate_product_name_format(params.name || ""),
         :ok <- ProductLogic.validate_non_zero_price(params.price || 0),
         {:ok, product_id} <- ProductId.new(params.id),
         {:ok, product_name} <- ProductName.new(params.name),
         {:ok, product_price} <- ProductPrice.new(params.price),
         {:ok, category_id} <- CategoryId.new(params.category_id) do

      # 純粋な関数でメタデータを生成
      metadata = AggregateLogic.build_command_metadata(params)

      event = ProductCreated.new(
        ProductId.value(product_id),
        ProductName.value(product_name),
        ProductPrice.value(product_price),
        CategoryId.value(category_id),
        metadata
      )

      {:ok, [event]}
    end
  end


  def execute(%__MODULE__{id: id} = aggregate, {:update_product, params}) when not is_nil(id) do
    # 純粋な関数でビジネスルールを適用
    with {:ok, validated_params} <- validate_and_filter_params(params),
         changes <- build_changes(aggregate, validated_params) do

      if map_size(changes) == 0 do
        {:ok, []}
      else
        metadata = AggregateLogic.build_command_metadata(params)

        event = ProductUpdated.new(
          ProductId.value(id),
          changes,
          metadata
        )

        # 純粋な関数で重要な価格変更かを判定
        events = if Map.has_key?(changes, :price) &&
                   AggregateLogic.is_significant_price_change?(
                     ProductPrice.value(aggregate.price),
                     changes.price,
                     10
                   ) do
          price_change_event = ProductPriceChanged.new(
            ProductId.value(id),
            ProductPrice.value(aggregate.price),
            changes.price,
            params[:price_change_reason] || "Price update",
            metadata
          )
          [event, price_change_event]
        else
          [event]
        end

        {:ok, events}
      end
    end
  end

  def execute(%__MODULE__{id: id}, {:delete_product, params}) when not is_nil(id) do
    metadata = AggregateLogic.build_command_metadata(params)

    event = ProductDeleted.new(
      ProductId.value(id),
      params[:reason] || "Product deleted",
      metadata
    )

    {:ok, [event]}
  end

  def execute(_aggregate, _command) do
    {:error, "Invalid command"}
  end

  # パラメータの検証とフィルタリング
  defp validate_and_filter_params(params) do
    filtered = ProductLogic.filter_update_params(params)
    ProductLogic.apply_price_update_rules(filtered)
  end


  # イベントハンドラー

  @impl true
  def apply_event(%__MODULE__{} = aggregate, %ProductCreated{} = event) do
    with {:ok, product_id} <- ProductId.new(event.aggregate_id),
         {:ok, product_name} <- ProductName.new(event.name),
         {:ok, product_price} <- ProductPrice.new(event.price),
         {:ok, category_id} <- CategoryId.new(event.category_id) do
      %__MODULE__{
        aggregate |
        id: product_id,
        name: product_name,
        price: product_price,
        category_id: category_id,
        deleted: false
      }
    else
      _ -> aggregate
    end
  end

  def apply_event(%__MODULE__{} = aggregate, %ProductUpdated{} = event) do
    Enum.reduce(event.changes, aggregate, fn
      {:name, new_name}, acc ->
        case ProductName.new(new_name) do
          {:ok, name} -> %{acc | name: name}
          _ -> acc
        end

      {:price, new_price}, acc ->
        case ProductPrice.new(new_price) do
          {:ok, price} -> %{acc | price: price}
          _ -> acc
        end

      {:category_id, new_category_id}, acc ->
        case CategoryId.new(new_category_id) do
          {:ok, category_id} -> %{acc | category_id: category_id}
          _ -> acc
        end

      _, acc -> acc
    end)
  end

  def apply_event(%__MODULE__{} = aggregate, %ProductDeleted{}) do
    %{aggregate | deleted: true}
  end

  def apply_event(%__MODULE__{} = aggregate, %ProductPriceChanged{}) do
    # このイベントは監査目的なので、状態変更は ProductUpdated で行う
    aggregate
  end

  def apply_event(aggregate, _event), do: aggregate

  # ヘルパー関数

  @spec build_changes(t(), map()) :: map()
  defp build_changes(aggregate, params) do
    changes = %{}

    changes = case params[:name] do
      nil -> changes
      "" -> changes
      new_name ->
        case ProductName.new(new_name) do
          {:ok, name} ->
            current_name = if aggregate.name, do: ProductName.value(aggregate.name), else: ""
            if ProductName.value(name) != current_name do
              Map.put(changes, :name, ProductName.value(name))
            else
              changes
            end
          _ -> changes
        end
    end

    changes = case params[:price] do
      nil -> changes
      new_price ->
        case ProductPrice.new(new_price) do
          {:ok, price} ->
            current_price = if aggregate.price, do: ProductPrice.value(aggregate.price), else: Decimal.new(0)
            if ProductPrice.value(price) != current_price do
              Map.put(changes, :price, ProductPrice.value(price))
            else
              changes
            end
          _ -> changes
        end
    end

    changes = case params[:category_id] do
      nil -> changes
      "" -> changes
      new_category_id ->
        case CategoryId.new(new_category_id) do
          {:ok, category_id} ->
            current_category = if aggregate.category_id, do: CategoryId.value(aggregate.category_id), else: ""
            if CategoryId.value(category_id) != current_category do
              Map.put(changes, :category_id, CategoryId.value(category_id))
            else
              changes
            end
          _ -> changes
        end
    end

    changes
  end

  # アクセサ

  @spec id(t()) :: String.t() | nil
  def id(%__MODULE__{id: nil}), do: nil
  def id(%__MODULE__{id: id}), do: ProductId.value(id)

  @spec name(t()) :: String.t() | nil
  def name(%__MODULE__{name: nil}), do: nil
  def name(%__MODULE__{name: name}), do: ProductName.value(name)

  @spec price(t()) :: Decimal.t() | nil
  def price(%__MODULE__{price: nil}), do: nil
  def price(%__MODULE__{price: price}), do: ProductPrice.value(price)

  @spec category_id(t()) :: String.t() | nil
  def category_id(%__MODULE__{category_id: nil}), do: nil
  def category_id(%__MODULE__{category_id: category_id}), do: CategoryId.value(category_id)

  @spec deleted?(t()) :: boolean()
  def deleted?(%__MODULE__{deleted: deleted}), do: deleted || false

  # ファクトリー関数

  @spec new() :: t()
  def new do
    %__MODULE__{
      id: nil,
      name: nil,
      price: nil,
      category_id: nil,
      deleted: false,
      version: 0,
      pending_events: []
    }
  end

  @spec new(String.t()) :: t()
  def new(id) when is_binary(id) do
    case ProductId.new(id) do
      {:ok, product_id} -> %__MODULE__{new() | id: product_id}
      _ -> new()
    end
  end
end
