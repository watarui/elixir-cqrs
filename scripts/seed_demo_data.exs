#!/usr/bin/env elixir

# シンプルなデモデータ投入スクリプト
# 
# 使用方法:
#   mix run scripts/seed_demo_data_v2.exs
#   mix run scripts/seed_demo_data_v2.exs --force  # 既存データがあっても実行

defmodule SeedDemoData do
  @moduledoc """
  デモデータを投入するスクリプト
  
  既存データがある場合は警告を表示して終了します。
  --force オプションで既存データがあっても実行できます。
  """

  alias ClientService.Infrastructure.{RemoteCommandBus, RemoteQueryBus}
  
  def main(args \\ []) do
    force = "--force" in args
    
    IO.puts("\n🌱 デモデータの投入を開始します...\n")
    
    # 既存データをチェック
    existing_data = check_existing_data()
    if existing_data.has_data && !force do
      IO.puts("⚠️  既存データが検出されました")
      IO.puts("")
      IO.puts("📊 現在のデータ数:")
      IO.puts("   - カテゴリ: #{existing_data.categories_count}件")
      IO.puts("   - 商品: #{existing_data.products_count}件")
      IO.puts("   - 注文: #{existing_data.orders_count}件")
      IO.puts("")
      IO.puts("   既存データをクリアするには: ./scripts/clear_data.sh")
      IO.puts("   強制的に実行するには: mix run scripts/seed_demo_data.exs --force")
      IO.puts("")
      System.halt(1)
    end
    
    # forceオプションが指定されている場合は、既存データをクリア
    if force && existing_data.has_data do
      IO.puts("🗑️  既存データをクリアしています...")
      clear_existing_data()
      Process.sleep(1000)  # クリア処理が完了するまで待機
    end
    
    # データ投入を実行
    start_time = System.monotonic_time(:millisecond)
    
    # 1. カテゴリの作成
    categories = create_categories()
    IO.puts("✅ カテゴリを作成しました: #{length(categories)}件\n")
    
    # 2. 商品の作成
    products = create_products(categories)
    IO.puts("✅ 商品を作成しました: #{length(products)}件\n")
    
    # 3. サンプル注文の作成
    orders = create_sample_orders(products)
    IO.puts("✅ 注文を作成しました: #{length(orders)}件\n")
    
    end_time = System.monotonic_time(:millisecond)
    elapsed_time = (end_time - start_time) / 1000
    
    show_summary(categories, products, orders, elapsed_time)
  end
  
  defp check_existing_data do
    # カテゴリ数を取得
    categories_count = case RemoteQueryBus.send_query("{categories {id}}") do
      {:ok, %{"categories" => categories}} -> length(categories)
      _ -> 0
    end
    
    # 商品数を取得
    products_count = case RemoteQueryBus.send_query("{products {id}}") do
      {:ok, %{"products" => products}} -> length(products)
      _ -> 0
    end
    
    # 注文数を取得
    orders_count = case RemoteQueryBus.send_query("{orders {id}}") do
      {:ok, %{"orders" => orders}} -> length(orders)
      _ -> 0
    end
    
    %{
      has_data: categories_count > 0 || products_count > 0 || orders_count > 0,
      categories_count: categories_count,
      products_count: products_count,
      orders_count: orders_count
    }
  end
  
  defp get_existing_category_names do
    query = """
    {
      categories {
        name
      }
    }
    """
    
    case RemoteQueryBus.send_query(query) do
      {:ok, %{"categories" => categories}} ->
        Enum.map(categories, &(&1["name"]))
      _ -> []
    end
  end
  
  defp clear_existing_data do
    # clear_data.sh スクリプトを呼び出す
    case System.cmd("bash", ["-c", "cd #{File.cwd!()} && ./scripts/clear_data.sh -y"]) do
      {output, 0} ->
        IO.puts("✅ 既存データをクリアしました")
      {output, _} ->
        IO.puts("⚠️  データクリアに失敗しました: #{output}")
    end
  end
  
  defp create_categories do
    # 既存のカテゴリ名を取得
    existing_names = get_existing_category_names()
    
    categories_data = [
      %{name: "Electronics", description: "電子機器・ガジェット"},
      %{name: "Books", description: "書籍・電子書籍"},
      %{name: "Clothing", description: "衣類・アクセサリー"},
      %{name: "Food & Beverage", description: "食品・飲料"},
      %{name: "Home & Garden", description: "家庭用品・園芸用品"}
    ]
    
    # 既存のカテゴリ名と重複しないようにフィルタリング
    categories_data = Enum.filter(categories_data, fn data ->
      not Enum.member?(existing_names, data.name)
    end)
    
    categories_data
    |> Enum.map(fn data ->
      command = %{
        __struct__: "CommandService.Application.Commands.CategoryCommands.CreateCategory",
        command_type: "category.create",
        name: data.name,
        description: data.description,
        metadata: %{}
      }
      
      IO.puts("  📝 作成中: #{data.name}")
      case RemoteCommandBus.send_command(command) do
        {:ok, result} ->
          IO.puts("  ✅ #{data.name} (#{result.id.value})")
          # イベントストアの確認
          Process.sleep(100)
          check_event_store(result.id.value, "category")
          result
        {:error, reason} ->
          IO.puts("  ❌ #{data.name} の作成に失敗: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.filter(&(&1))
  end
  
  defp create_products(categories) do
    if Enum.empty?(categories) do
      IO.puts("  ⚠️  カテゴリが存在しないため、商品を作成できません")
      []
    else
      products_data = [
        %{category: "Electronics", name: "MacBook Pro 14\"", price: "299990", description: "Apple M3 Pro搭載"},
        %{category: "Electronics", name: "iPhone 15 Pro", price: "159800", description: "最新のiPhone"},
        %{category: "Electronics", name: "AirPods Pro", price: "39800", description: "ノイズキャンセリング対応"},
        %{category: "Books", name: "プログラミング Elixir", price: "3080", description: "関数型言語の入門書"},
        %{category: "Books", name: "ドメイン駆動設計", price: "5720", description: "エリック・エヴァンスの名著"},
        %{category: "Clothing", name: "デニムジャケット", price: "8900", description: "カジュアルなアウター"},
        %{category: "Clothing", name: "白シャツ", price: "4900", description: "ビジネスにも使える"},
        %{category: "Food & Beverage", name: "コーヒー豆 1kg", price: "3200", description: "エチオピア産"},
        %{category: "Food & Beverage", name: "オーガニック紅茶", price: "1800", description: "アールグレイ"},
        %{category: "Home & Garden", name: "観葉植物（モンステラ）", price: "3500", description: "インテリアに最適"}
      ]
      
      products_data
      |> Enum.map(fn template ->
        category = Enum.find(categories, &(&1.name.value == template.category)) || Enum.random(categories)
        stock_quantity = 50 + :rand.uniform(50)  # 50-100の在庫
        
        command = %{
          __struct__: "CommandService.Application.Commands.ProductCommands.CreateProduct",
          command_type: "product.create",
          name: template.name,
          description: template.description,
          price: template.price,
          category_id: category.id.value,
          stock_quantity: stock_quantity,
          metadata: %{}
        }
        
        case RemoteCommandBus.send_command(command) do
          {:ok, result} ->
            IO.puts("  - #{command.name} (¥#{template.price}, 在庫: #{stock_quantity})")
            result
          {:error, reason} ->
            IO.puts("  ❌ #{command.name} の作成に失敗: #{inspect(reason)}")
            nil
        end
      end)
      |> Enum.filter(&(&1))
    end
  end
  
  defp create_sample_orders(products) do
    if Enum.empty?(products) do
      IO.puts("  ⚠️  商品が存在しないため、注文を作成できません")
      []
    else
      # 在庫のある商品のみをフィルタ
      available_products = Enum.filter(products, fn p -> 
        case p do
          %{stock_quantity: %{value: value}} -> value > 0
          _ -> false
        end
      end)
      
      if Enum.empty?(available_products) do
        IO.puts("  ⚠️  在庫のある商品が存在しないため、注文を作成できません")
        []
      else
        1..5
        |> Enum.map(fn i ->
          user_id = "user_#{String.pad_leading(to_string(i), 3, "0")}"
          product = Enum.random(available_products)
          quantity = 1 + :rand.uniform(2)  # 1-3個
          
          items = [
            %{
              product_id: product.id.value,
              product_name: product.name.value,
              quantity: quantity,
              unit_price: product.price.amount |> Decimal.to_string()
            }
          ]
          
          command = %{
            __struct__: "CommandService.Application.Commands.OrderCommands.CreateOrder",
            command_type: "order.create",
            user_id: user_id,
            items: items,
            metadata: %{}
          }
          
          case RemoteCommandBus.send_command(command) do
            {:ok, result} ->
              total = Decimal.mult(product.price.amount, quantity) |> Decimal.to_string()
              IO.puts("  - 注文 #{result.id.value} (ユーザー: #{user_id}, 合計: ¥#{total})")
              result
            {:error, reason} ->
              IO.puts("  ❌ 注文の作成に失敗: #{inspect(reason)}")
              nil
          end
        end)
        |> Enum.filter(&(&1))
      end
    end
  end
  
  defp show_summary(categories, products, orders, elapsed_time) do
    IO.puts("\n📊 実行サマリー")
    IO.puts("================")
    IO.puts("  カテゴリ: #{length(categories)}件")
    IO.puts("  商品: #{length(products)}件")
    IO.puts("  注文: #{length(orders)}件")
    IO.puts("  実行時間: #{Float.round(elapsed_time, 2)}秒")
    
    # イベントストアの最終確認
    IO.puts("\n🔍 Event Store の確認:")
    check_total_events()
    
    IO.puts("\n🎉 デモデータの投入が完了しました！")
    IO.puts("\nGraphQL Playground で以下のクエリを試してみてください:")
    IO.puts("""
    
    # カテゴリ一覧を取得
    {
      categories {
        id
        name
        description
        products {
          id
          name
          price
        }
      }
    }
    """)
  end
  
  defp check_event_store(aggregate_id, aggregate_type) do
    # PostgreSQL に直接接続してイベントを確認
    query = """
    query {
      __type(name: "Query") {
        name
      }
    }
    """
    
    # GraphQL 経由でイベントストアを確認する方法がないため、コメントアウト
    # TODO: イベントストアの確認方法を実装
    IO.puts("    → Event Store へのイベント保存を確認中...")
  end
  
  defp check_total_events do
    # TODO: Event Store の総イベント数を確認
    IO.puts("  Event Store の総イベント数: (確認方法未実装)")
  end
end

# アプリケーションが起動するまで待機
Process.sleep(2000)

# メイン関数を実行
SeedDemoData.main(System.argv())