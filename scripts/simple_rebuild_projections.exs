#!/usr/bin/env elixir
# シンプルなプロジェクション再構築スクリプト

# Mix の初期化
Mix.start()
Mix.Task.run("app.start")

require Logger

Logger.info("プロジェクションの再構築を開始します...")

# 既存のカテゴリを全て削除
{deleted_count, _} = QueryService.Repo.delete_all(QueryService.Infrastructure.Repositories.CategoryRepository.CategorySchema)
Logger.info("#{deleted_count} 件のカテゴリを削除しました。")

# イベントストアから全イベントを取得
import Ecto.Query
events = Shared.Infrastructure.EventStore.Repo.all(
  from e in Shared.Infrastructure.EventStore.Schema.Event,
  order_by: [asc: e.global_sequence]
)

Logger.info("#{length(events)} 件のイベントを取得しました。")

# カテゴリイベントを処理
category_events = Enum.filter(events, fn event ->
  event.event_type in ["category.created", "category.updated", "category.deleted"]
end)

product_events = Enum.filter(events, fn event ->
  event.event_type in ["product.created", "product.updated", "product.price_changed", "product.deleted"]
end)

Logger.info("カテゴリイベント: #{length(category_events)} 件")
Logger.info("商品イベント: #{length(product_events)} 件")

# カテゴリイベントを処理
Enum.each(category_events, fn event ->
  case event.event_type do
    "category.created" ->
      attrs = %{
        id: event.event_data["id"]["value"],
        name: event.event_data["name"]["value"],
        description: event.event_data["description"],
        parent_id: event.event_data["parent_id"],
        active: true,
        product_count: 0,
        metadata: %{}
      }
      
      case QueryService.Infrastructure.Repositories.CategoryRepository.create(attrs) do
        {:ok, _} ->
          Logger.info("カテゴリを作成: #{attrs.name}")
        {:error, reason} ->
          Logger.error("カテゴリ作成失敗: #{inspect(reason)}")
      end
      
    "category.updated" ->
      id = event.event_data["id"]["value"]
      attrs = %{
        name: event.event_data["name"]["value"],
        description: event.event_data["description"]
      }
      
      case QueryService.Infrastructure.Repositories.CategoryRepository.update(id, attrs) do
        {:ok, _} ->
          Logger.info("カテゴリを更新: #{id}")
        {:error, reason} ->
          Logger.error("カテゴリ更新失敗: #{inspect(reason)}")
      end
      
    "category.deleted" ->
      id = event.event_data["id"]["value"]
      
      case QueryService.Infrastructure.Repositories.CategoryRepository.delete(id) do
        {:ok, _} ->
          Logger.info("カテゴリを削除: #{id}")
        {:error, reason} ->
          Logger.error("カテゴリ削除失敗: #{inspect(reason)}")
      end
  end
end)

# 商品イベントを処理
Enum.each(product_events, fn event ->
  case event.event_type do
    "product.created" ->
      # カテゴリ名を取得
      category_id = event.event_data["category_id"]["value"]
      category_name = case QueryService.Infrastructure.Repositories.CategoryRepository.get(category_id) do
        {:ok, category} -> category.name
        _ -> "Unknown Category"
      end
      
      attrs = %{
        id: event.event_data["id"]["value"],
        name: event.event_data["name"]["value"],
        description: event.event_data["description"],
        category_id: category_id,
        category_name: category_name,
        price_amount: Decimal.new(to_string(event.event_data["price"]["amount"])),
        price_currency: event.event_data["price"]["currency"],
        stock_quantity: event.event_data["stock_quantity"],
        active: true,
        metadata: %{}
      }
      
      case QueryService.Infrastructure.Repositories.ProductRepository.create(attrs) do
        {:ok, _} ->
          Logger.info("商品を作成: #{attrs.name}")
        {:error, reason} ->
          Logger.error("商品作成失敗: #{inspect(reason)}")
      end
      
    "product.updated" ->
      id = event.event_data["id"]["value"]
      category_id = event.event_data["category_id"]["value"]
      
      # カテゴリ名を取得
      category_name = case QueryService.Infrastructure.Repositories.CategoryRepository.get(category_id) do
        {:ok, category} -> category.name
        _ -> "Unknown Category"
      end
      
      attrs = %{
        name: event.event_data["name"]["value"],
        description: event.event_data["description"],
        category_id: category_id,
        category_name: category_name
      }
      
      case QueryService.Infrastructure.Repositories.ProductRepository.update(id, attrs) do
        {:ok, _} ->
          Logger.info("商品を更新: #{id}")
        {:error, reason} ->
          Logger.error("商品更新失敗: #{inspect(reason)}")
      end
      
    "product.price_changed" ->
      id = event.event_data["id"]["value"]
      attrs = %{
        price_amount: Decimal.new(to_string(event.event_data["new_price"]["amount"])),
        price_currency: event.event_data["new_price"]["currency"]
      }
      
      case QueryService.Infrastructure.Repositories.ProductRepository.update(id, attrs) do
        {:ok, _} ->
          Logger.info("商品価格を更新: #{id}")
        {:error, reason} ->
          Logger.error("商品価格更新失敗: #{inspect(reason)}")
      end
      
    "product.deleted" ->
      id = event.event_data["id"]["value"]
      
      case QueryService.Infrastructure.Repositories.ProductRepository.delete(id) do
        {:ok, _} ->
          Logger.info("商品を削除: #{id}")
        {:error, reason} ->
          Logger.error("商品削除失敗: #{inspect(reason)}")
      end
  end
end)

# 結果を確認
Logger.info("\n現在のデータ:")

# カテゴリ数を確認
category_count = QueryService.Repo.aggregate("categories", :count, :id)
Logger.info("カテゴリ数: #{category_count}")

# 商品数を確認  
product_count = QueryService.Repo.aggregate("products", :count, :id)
Logger.info("商品数: #{product_count}")

# カテゴリ一覧を表示
categories = QueryService.Repo.all(QueryService.Infrastructure.Repositories.CategoryRepository.CategorySchema)
Enum.each(categories, fn category ->
  Logger.info("- #{category.name} (#{category.id})")
end)

# 商品一覧を表示
products = QueryService.Repo.all(QueryService.Infrastructure.Repositories.ProductRepository.ProductSchema)
Enum.each(products, fn product ->
  Logger.info("- #{product.name} (#{product.id}) - カテゴリ: #{product.category_id}")
end)