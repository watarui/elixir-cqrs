defmodule QueryService.Application.ProjectionManager do
  @moduledoc """
  プロジェクションマネージャー

  イベントストアからのイベントを監視し、
  読み取りモデル（Query Service DB）に投影します
  """

  use GenServer
  require Logger

  alias Shared.Infrastructure.{EventBus, EventStore}

  alias Shared.Domain.Events.ProductEvents.{
    ProductCreated,
    ProductDeleted,
    ProductPriceChanged,
    ProductUpdated
  }

  alias Shared.Domain.Events.CategoryEvents.{
    CategoryCreated,
    CategoryDeleted,
    CategoryUpdated
  }

  # 1秒ごとにポーリング
  @poll_interval 1000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def project_event(event) do
    GenServer.cast(__MODULE__, {:project_event, event})
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    Logger.info("ProjectionManager starting...")

    # 初期状態
    state = %{
      last_position: 0,
      handlers: build_handlers(),
      query_repo: opts[:query_repo] || QueryService.Infrastructure.Database.Repo,
      poll_interval: opts[:poll_interval] || @poll_interval
    }

    # イベントバスに登録
    EventBus.subscribe(self())

    # ポーリングを開始
    Logger.info("Scheduling first poll in #{state.poll_interval}ms")
    schedule_poll(state.poll_interval)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:project_event, event}, state) do
    handle_event(event, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:event, event}, state) do
    # イベントバスからのイベントを処理
    handle_event(event, state)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:poll_events, state) do
    Logger.debug("Polling events from position #{state.last_position}")

    # イベントストアから新しいイベントを取得
    case EventStore.read_all_events(state.last_position) do
      {:ok, events} when events != [] ->
        Logger.info("Found #{length(events)} new events to project")

        # 各イベントを処理
        new_position =
          Enum.reduce(events, state.last_position, fn event, pos ->
            handle_event(event, state)
            pos + 1
          end)

        # 次回のポーリングをスケジュール
        schedule_poll(state.poll_interval)

        {:noreply, %{state | last_position: new_position}}

      {:ok, []} ->
        Logger.debug("No new events found")
        # イベントがない場合も次回のポーリングをスケジュール
        schedule_poll(state.poll_interval)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to read events: #{inspect(reason)}")
        # エラーの場合も次回のポーリングをスケジュール
        schedule_poll(state.poll_interval)
        {:noreply, state}
    end
  end

  # Private functions

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll_events, interval)
  end

  defp build_handlers do
    %{
      ProductCreated => &handle_product_created/2,
      ProductUpdated => &handle_product_updated/2,
      ProductDeleted => &handle_product_deleted/2,
      ProductPriceChanged => &handle_product_price_changed/2,
      CategoryCreated => &handle_category_created/2,
      CategoryUpdated => &handle_category_updated/2,
      CategoryDeleted => &handle_category_deleted/2
    }
  end

  defp handle_event(event, state) do
    event_type = event.__struct__

    case Map.get(state.handlers, event_type) do
      nil ->
        Logger.warning("No handler for event type: #{inspect(event_type)}")

      handler ->
        try do
          handler.(event, state)
          Logger.info("Projected event: #{inspect(event_type)}")
        rescue
          e ->
            Logger.error("Error projecting event: #{inspect(e)}")
        end
    end
  end

  # Product event handlers

  defp handle_product_created(%ProductCreated{} = event, state) do
    # Query Service DBに商品を作成
    product_schema = %QueryService.Infrastructure.Database.Schemas.ProductSchema{
      id: event.aggregate_id,
      name: event.name,
      price: convert_to_decimal(event.price),
      category_id: event.category_id,
      inserted_at: truncate_to_second(event.occurred_at),
      updated_at: truncate_to_second(event.occurred_at)
    }

    case state.query_repo.insert(product_schema) do
      {:ok, _} ->
        Logger.info("Product created in read model: #{event.aggregate_id}")

      {:error, reason} ->
        Logger.error("Failed to create product in read model: #{inspect(reason)}")
    end
  end

  defp handle_product_updated(%ProductUpdated{} = event, state) do
    # Query Service DBの商品を更新
    case state.query_repo.get(
           QueryService.Infrastructure.Database.Schemas.ProductSchema,
           event.aggregate_id
         ) do
      nil ->
        Logger.warning("Product not found for update: #{event.aggregate_id}")

      product ->
        changes =
          Enum.reduce(event.changes, %{}, fn
            {:name, name}, acc -> Map.put(acc, :name, name)
            {:price, price}, acc -> Map.put(acc, :price, convert_to_decimal(price))
            {:category_id, category_id}, acc -> Map.put(acc, :category_id, category_id)
            _, acc -> acc
          end)
          |> Map.put(:updated_at, truncate_to_second(event.occurred_at))

        changeset = Ecto.Changeset.change(product, changes)

        case state.query_repo.update(changeset) do
          {:ok, _} ->
            Logger.info("Product updated in read model: #{event.aggregate_id}")

          {:error, reason} ->
            Logger.error("Failed to update product in read model: #{inspect(reason)}")
        end
    end
  end

  defp handle_product_deleted(%ProductDeleted{} = event, state) do
    # Query Service DBから商品を削除
    case state.query_repo.get(
           QueryService.Infrastructure.Database.Schemas.ProductSchema,
           event.aggregate_id
         ) do
      nil ->
        Logger.warning("Product not found for deletion: #{event.aggregate_id}")

      product ->
        case state.query_repo.delete(product) do
          {:ok, _} ->
            Logger.info("Product deleted from read model: #{event.aggregate_id}")

          {:error, reason} ->
            Logger.error("Failed to delete product from read model: #{inspect(reason)}")
        end
    end
  end

  defp handle_product_price_changed(%ProductPriceChanged{} = event, _state) do
    # 価格変更は監査ログとして記録（実際の更新はProductUpdatedで行われる）
    Logger.info(
      "Product price changed: #{event.aggregate_id} from #{event.old_price} to #{event.new_price}"
    )
  end

  # Category event handlers

  defp handle_category_created(%CategoryCreated{} = event, state) do
    # Query Service DBにカテゴリを作成
    category_schema = %QueryService.Infrastructure.Database.Schemas.CategorySchema{
      id: event.aggregate_id,
      name: event.name,
      inserted_at: truncate_to_second(event.occurred_at),
      updated_at: truncate_to_second(event.occurred_at)
    }

    case state.query_repo.insert(category_schema) do
      {:ok, _} ->
        Logger.info("Category created in read model: #{event.aggregate_id}")

      {:error, reason} ->
        Logger.error("Failed to create category in read model: #{inspect(reason)}")
    end
  end

  defp handle_category_updated(%CategoryUpdated{} = event, state) do
    # Query Service DBのカテゴリを更新
    case state.query_repo.get(
           QueryService.Infrastructure.Database.Schemas.CategorySchema,
           event.aggregate_id
         ) do
      nil ->
        Logger.warning("Category not found for update: #{event.aggregate_id}")

      category ->
        changeset =
          Ecto.Changeset.change(category, %{
            name: event.new_name,
            updated_at: truncate_to_second(event.occurred_at)
          })

        case state.query_repo.update(changeset) do
          {:ok, _} ->
            Logger.info("Category updated in read model: #{event.aggregate_id}")

          {:error, reason} ->
            Logger.error("Failed to update category in read model: #{inspect(reason)}")
        end
    end
  end

  defp handle_category_deleted(%CategoryDeleted{} = event, state) do
    # Query Service DBからカテゴリを削除
    case state.query_repo.get(
           QueryService.Infrastructure.Database.Schemas.CategorySchema,
           event.aggregate_id
         ) do
      nil ->
        Logger.warning("Category not found for deletion: #{event.aggregate_id}")

      category ->
        case state.query_repo.delete(category) do
          {:ok, _} ->
            Logger.info("Category deleted from read model: #{event.aggregate_id}")

          {:error, reason} ->
            Logger.error("Failed to delete category from read model: #{inspect(reason)}")
        end
    end
  end

  # DateTime をマイクロ秒なしに切り捨てる
  defp truncate_to_second(nil), do: nil

  defp truncate_to_second(%DateTime{} = datetime) do
    DateTime.truncate(datetime, :second)
  end

  defp truncate_to_second(%NaiveDateTime{} = datetime) do
    NaiveDateTime.truncate(datetime, :second)
  end

  # 文字列またはその他の値をDecimalに変換
  defp convert_to_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0")
    end
  end

  defp convert_to_decimal(value) when is_float(value) do
    Decimal.from_float(value)
  end

  defp convert_to_decimal(value) when is_integer(value) do
    Decimal.new(value)
  end

  defp convert_to_decimal(%Decimal{} = value), do: value
  defp convert_to_decimal(_), do: Decimal.new("0")
end
