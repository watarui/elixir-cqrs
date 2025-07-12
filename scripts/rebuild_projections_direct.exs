#!/usr/bin/env elixir

# プロジェクションを直接SQLで再構築するスクリプト
#
# 使用方法:
#   mix run scripts/rebuild_projections_direct.exs

# 必要なアプリケーションを起動
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:jason)

IO.puts("\n🔄 プロジェクションの再構築を開始します...\n")

# データベース設定
event_store_config = [
  hostname: "localhost",
  port: 5432,
  username: "postgres",
  password: "postgres",
  database: "elixir_cqrs_event_store_dev"
]

query_db_config = [
  hostname: "localhost",
  port: 5434,
  username: "postgres",
  password: "postgres",
  database: "elixir_cqrs_query_dev"
]

# Event Store に接続
{:ok, event_conn} = Postgrex.start_link(event_store_config)
IO.puts("✅ Event Store に接続しました")

# Query DB に接続
{:ok, query_conn} = Postgrex.start_link(query_db_config)
IO.puts("✅ Query DB に接続しました")

# 現在の状態を表示
IO.puts("\n📊 現在の状態:")

# Event Store のイベント数
{:ok, %{rows: [[event_count]]}} = Postgrex.query(event_conn, "SELECT COUNT(*) FROM events", [])
IO.puts("  Event Store: #{event_count} イベント")

# Query DB の状態
{:ok, %{rows: [[category_count]]}} = Postgrex.query(query_conn, "SELECT COUNT(*) FROM categories", [])
{:ok, %{rows: [[product_count]]}} = Postgrex.query(query_conn, "SELECT COUNT(*) FROM products", [])
{:ok, %{rows: [[order_count]]}} = Postgrex.query(query_conn, "SELECT COUNT(*) FROM orders", [])

IO.puts("  Query DB:")
IO.puts("    - カテゴリ: #{category_count} 件")
IO.puts("    - 商品: #{product_count} 件")
IO.puts("    - 注文: #{order_count} 件")

# プロジェクションをクリア
IO.puts("\n🧹 既存のプロジェクションをクリア中...")
{:ok, _} = Postgrex.query(query_conn, "TRUNCATE TABLE categories CASCADE", [])
{:ok, _} = Postgrex.query(query_conn, "TRUNCATE TABLE products CASCADE", [])
{:ok, _} = Postgrex.query(query_conn, "TRUNCATE TABLE orders CASCADE", [])
IO.puts("  ✓ プロジェクションをクリアしました")

# イベントを取得して処理
IO.puts("\n📚 イベントを処理中...")

# すべてのイベントを取得
{:ok, %{rows: events}} = Postgrex.query(
  event_conn,
  """
  SELECT 
    id,
    aggregate_id,
    aggregate_type,
    event_type,
    event_data,
    event_version,
    global_sequence,
    inserted_at
  FROM events
  ORDER BY global_sequence ASC
  """,
  []
)

IO.puts("  処理するイベント数: #{length(events)}")

# イベントタイプ別にカウント
event_types = Enum.group_by(events, fn [_, _, _, event_type, _, _, _, _] -> event_type end)
|> Enum.map(fn {type, events} -> {type, length(events)} end)
|> Enum.sort()

IO.puts("\n  イベントタイプ別:")
Enum.each(event_types, fn {type, count} ->
  IO.puts("    - #{type}: #{count} 件")
end)

# ヘルパー関数
get_id = fn
  nil -> nil
  %{"value" => value} when is_binary(value) -> 
    # UUIDフォーマットかチェック
    case String.match?(value, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) do
      true ->
        case Ecto.UUID.dump(value) do
          {:ok, uuid} -> uuid
          _ -> value
        end
      false -> value
    end
  # %{"value" => ...} のようなマップの場合（valueが存在しない）
  map when is_map(map) ->
    IO.puts("  ⚠️  予期しないマップ形式: #{inspect(map)}")
    nil
  id when is_binary(id) and byte_size(id) == 36 -> 
    # UUIDフォーマットかチェック
    case String.match?(id, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i) do
      true ->
        case Ecto.UUID.dump(id) do
          {:ok, uuid} -> uuid
          _ -> id
        end
      false -> id
    end
  id when is_binary(id) and byte_size(id) == 16 ->
    # 既にバイナリUUID
    id
  id -> 
    IO.puts("  ⚠️  予期しない形式のID: #{inspect(id)}")
    id
end

get_value = fn
  nil -> nil
  %{"value" => value} -> value
  value when is_binary(value) -> value
end

get_amount = fn
  nil -> Decimal.new("0")
  %{"amount" => amount} -> Decimal.new(to_string(amount))
  amount -> Decimal.new(to_string(amount))
end

get_currency = fn
  nil -> "JPY"
  %{"currency" => currency} -> currency
  _ -> "JPY"
end

# 各イベントを処理
IO.puts("\n  処理中...")

processed = Enum.reduce(events, %{categories: 0, products: 0, orders: 0}, fn event, acc ->
  [_id, aggregate_id, _aggregate_type, event_type, event_data, _event_version, _global_sequence, inserted_at] = event
  
  case event_type do
    "category.created" ->
      data = event_data
      
      case Postgrex.query(
        query_conn,
        """
        INSERT INTO categories (id, name, description, parent_id, active, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $6)
        ON CONFLICT (id) DO NOTHING
        """,
        [
          get_id.(data["id"]),
          get_value.(data["name"]),
          data["description"],
          get_id.(data["parent_id"]),
          true,
          inserted_at
        ]
      ) do
        {:ok, _} -> Map.update!(acc, :categories, &(&1 + 1))
        {:error, e} -> 
          IO.puts("  ⚠️  カテゴリ作成エラー: #{inspect(e)}")
          IO.puts("    data[\"id\"]: #{inspect(data["id"])}")
          acc
      end
      
    "category.updated" ->
      data = event_data
      
      case Postgrex.query(
        query_conn,
        """
        UPDATE categories 
        SET name = $2, description = $3, parent_id = $4, updated_at = $5
        WHERE id = $1
        """,
        [
          get_id.(data["id"]),
          get_value.(data["name"]),
          data["description"],
          get_id.(data["parent_id"]),
          inserted_at
        ]
      ) do
        {:ok, _} -> Map.update!(acc, :categories, &(&1 + 1))
        {:error, e} -> 
          IO.puts("  ⚠️  カテゴリ更新エラー: #{inspect(e)}")
          acc
      end
      
    "category.deleted" ->
      data = event_data
      
      case Postgrex.query(
        query_conn,
        "DELETE FROM categories WHERE id = $1",
        [get_id.(data["id"])]
      ) do
        {:ok, _} -> Map.update!(acc, :categories, &(&1 + 1))
        {:error, e} -> 
          IO.puts("  ⚠️  カテゴリ削除エラー: #{inspect(e)}")
          acc
      end
      
    "product.created" ->
      data = event_data
      price_data = data["price"] || %{}
      
      case Postgrex.query(
        query_conn,
        """
        INSERT INTO products (id, name, description, category_id, category_name, price_amount, price_currency, stock_quantity, active, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $10)
        ON CONFLICT (id) DO NOTHING
        """,
        [
          get_id.(data["id"]),
          get_value.(data["name"]),
          data["description"],
          get_id.(data["category_id"]),
          "Unknown",  # category_name は後で更新
          get_amount.(price_data),
          get_currency.(price_data),
          data["stock_quantity"] || 0,
          true,
          inserted_at
        ]
      ) do
        {:ok, _} -> Map.update!(acc, :products, &(&1 + 1))
        {:error, e} -> 
          IO.puts("  ⚠️  商品作成エラー: #{inspect(e)}")
          acc
      end
      
    "product.updated" ->
      data = event_data
      
      case Postgrex.query(
        query_conn,
        """
        UPDATE products 
        SET name = $2, description = $3, category_id = $4, updated_at = $5
        WHERE id = $1
        """,
        [
          get_id.(data["id"]),
          get_value.(data["name"]),
          data["description"],
          get_id.(data["category_id"]),
          inserted_at
        ]
      ) do
        {:ok, _} -> Map.update!(acc, :products, &(&1 + 1))
        {:error, e} -> 
          IO.puts("  ⚠️  商品更新エラー: #{inspect(e)}")
          acc
      end
      
    "product.price_changed" ->
      data = event_data
      new_price = data["new_price"] || %{}
      
      case Postgrex.query(
        query_conn,
        """
        UPDATE products 
        SET price_amount = $2, price_currency = $3, updated_at = $4
        WHERE id = $1
        """,
        [
          get_id.(data["id"]),
          get_amount.(new_price),
          get_currency.(new_price),
          inserted_at
        ]
      ) do
        {:ok, _} -> Map.update!(acc, :products, &(&1 + 1))
        {:error, e} -> 
          IO.puts("  ⚠️  商品価格変更エラー: #{inspect(e)}")
          acc
      end
      
    "product.deleted" ->
      data = event_data
      
      case Postgrex.query(
        query_conn,
        "DELETE FROM products WHERE id = $1",
        [get_id.(data["id"])]
      ) do
        {:ok, _} -> Map.update!(acc, :products, &(&1 + 1))
        {:error, e} -> 
          IO.puts("  ⚠️  商品削除エラー: #{inspect(e)}")
          acc
      end
      
    "order.created" ->
      data = event_data
      
      # aggregate_id を正しく処理
      order_id = case aggregate_id do
        id when is_binary(id) and byte_size(id) == 36 ->
          case Ecto.UUID.dump(id) do
            {:ok, uuid} -> uuid
            _ -> id
          end
        id when is_binary(id) and byte_size(id) == 16 -> id
        _ -> aggregate_id
      end
      
      # 注文アイテムのJSON形式
      items = Enum.map(data["items"] || [], fn item ->
        product_id = case item["product_id"] do
          %{"value" => value} -> value
          id when is_binary(id) -> id
          _ -> nil
        end
        
        %{
          "product_id" => product_id,
          "quantity" => item["quantity"],
          "price" => Decimal.to_string(get_amount.(item["price"])),
          "currency" => get_currency.(item["price"])
        }
      end)
      
      total_amount = data["total_amount"] || %{}
      
      case Postgrex.query(
        query_conn,
        """
        INSERT INTO orders (id, user_id, status, items, total_amount, currency, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
        ON CONFLICT (id) DO NOTHING
        """,
        [
          order_id,
          data["user_id"],
          "created",
          Jason.encode!(items),
          get_amount.(total_amount),
          get_currency.(total_amount),
          inserted_at
        ]
      ) do
        {:ok, _} -> Map.update!(acc, :orders, &(&1 + 1))
        {:error, e} -> 
          IO.puts("  ⚠️  注文作成エラー: #{inspect(e)}")
          IO.puts("    aggregate_id: #{inspect(aggregate_id)}")
          IO.puts("    order_id: #{inspect(order_id)}")
          acc
      end
      
    _ ->
      # その他のイベントはスキップ
      acc
  end
end)

IO.puts("\n  処理結果:")
IO.puts("    - カテゴリイベント: #{processed.categories} 件")
IO.puts("    - 商品イベント: #{processed.products} 件")
IO.puts("    - 注文イベント: #{processed.orders} 件")

# 最終的な状態を表示
IO.puts("\n✅ 完了後の状態:")

# Query DB の状態
{:ok, %{rows: [[category_count]]}} = Postgrex.query(query_conn, "SELECT COUNT(*) FROM categories", [])
{:ok, %{rows: [[product_count]]}} = Postgrex.query(query_conn, "SELECT COUNT(*) FROM products", [])
{:ok, %{rows: [[order_count]]}} = Postgrex.query(query_conn, "SELECT COUNT(*) FROM orders", [])

IO.puts("  Query DB:")
IO.puts("    - カテゴリ: #{category_count} 件")
IO.puts("    - 商品: #{product_count} 件")
IO.puts("    - 注文: #{order_count} 件")

# 接続を閉じる
GenServer.stop(event_conn)
GenServer.stop(query_conn)

IO.puts("\n✨ プロジェクションの再構築が完了しました！")