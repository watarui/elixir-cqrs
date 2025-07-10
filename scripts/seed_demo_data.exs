#!/usr/bin/env elixir

# デモデータ投入スクリプト
# 
# 使用方法:
#   mix run scripts/seed_demo_data.exs

defmodule SeedDemoData do
  @moduledoc """
  デモデータを投入するスクリプト
  
  カテゴリ、商品、注文のサンプルデータを作成します
  """

  alias ClientService.Infrastructure.{RemoteCommandBus, RemoteQueryBus}
  
  def run do
    IO.puts("\n🌱 デモデータの投入を開始します...\n")
    
    # 1. カテゴリの作成
    categories = create_categories()
    IO.puts("✅ カテゴリを作成しました: #{length(categories)}件\n")
    
    # 2. 商品の作成
    products = create_products(categories)
    IO.puts("✅ 商品を作成しました: #{length(products)}件\n")
    
    # 3. サンプル注文の作成
    orders = create_sample_orders(products)
    IO.puts("✅ 注文を作成しました: #{length(orders)}件\n")
    
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
    
    # 商品一覧を取得
    {
      products {
        id
        name
        price
        category {
          name
        }
      }
    }
    """)
  end
  
  defp create_categories do
    categories_data = [
      %{name: "Electronics", description: "電子機器・ガジェット"},
      %{name: "Books", description: "書籍・電子書籍"},
      %{name: "Clothing", description: "衣類・アクセサリー"},
      %{name: "Food & Beverage", description: "食品・飲料"},
      %{name: "Home & Garden", description: "家庭用品・園芸用品"}
    ]
    
    Enum.map(categories_data, fn data ->
      command = %{
        __struct__: "CommandService.Application.Commands.CategoryCommands.CreateCategory",
        command_type: "category.create",
        name: data.name,
        description: data.description,
        metadata: %{}
      }
      
      case RemoteCommandBus.send_command(command) do
        {:ok, result} ->
          IO.puts("  - #{data.name} (#{result.id.value})")
          result
        {:error, reason} ->
          IO.puts("  ❌ #{data.name} の作成に失敗: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.filter(&(&1))
  end
  
  defp create_products(categories) do
    products_data = [
      # Electronics
      %{category: "Electronics", name: "MacBook Pro 14\"", price: "299990", description: "Apple M3 Pro搭載"},
      %{category: "Electronics", name: "iPhone 15 Pro", price: "159800", description: "最新のiPhone"},
      %{category: "Electronics", name: "AirPods Pro", price: "39800", description: "ノイズキャンセリング対応"},
      
      # Books
      %{category: "Books", name: "プログラミング Elixir", price: "3080", description: "関数型言語の入門書"},
      %{category: "Books", name: "ドメイン駆動設計", price: "5720", description: "エリック・エヴァンスの名著"},
      %{category: "Books", name: "マイクロサービスパターン", price: "5280", description: "実践的な設計パターン"},
      
      # Clothing
      %{category: "Clothing", name: "デニムジャケット", price: "8900", description: "カジュアルなアウター"},
      %{category: "Clothing", name: "白シャツ", price: "4900", description: "ビジネスにも使える"},
      %{category: "Clothing", name: "スニーカー", price: "12000", description: "快適な履き心地"},
      
      # Food & Beverage
      %{category: "Food & Beverage", name: "コーヒー豆 1kg", price: "3200", description: "エチオピア産"},
      %{category: "Food & Beverage", name: "オーガニック紅茶", price: "1800", description: "アールグレイ"},
      %{category: "Food & Beverage", name: "ダークチョコレート", price: "680", description: "カカオ70%"},
      
      # Home & Garden
      %{category: "Home & Garden", name: "観葉植物（モンステラ）", price: "3500", description: "インテリアに最適"},
      %{category: "Home & Garden", name: "アロマディフューザー", price: "4500", description: "リラックス空間を演出"},
      %{category: "Home & Garden", name: "クッション", price: "2800", description: "北欧デザイン"}
    ]
    
    Enum.map(products_data, fn data ->
      category = Enum.find(categories, &(&1.name.value == data.category))
      
      if category do
        command = %{
          __struct__: "CommandService.Application.Commands.ProductCommands.CreateProduct",
          command_type: "product.create",
          name: data.name,
          description: data.description,
          price: data.price,
          category_id: category.id.value,
          stock_quantity: 100,
          metadata: %{}
        }
        
        case RemoteCommandBus.send_command(command) do
          {:ok, result} ->
            IO.puts("  - #{data.name} (#{data.category})")
            result
          {:error, reason} ->
            IO.puts("  ❌ #{data.name} の作成に失敗: #{inspect(reason)}")
            nil
        end
      end
    end)
    |> Enum.filter(&(&1))
  end
  
  defp create_sample_orders(products) do
    # 商品情報を取得してマップを作成
    product_map = products
    |> Enum.map(fn p -> {p.id.value, p} end)
    |> Map.new()
    
    orders_data = [
      # 成功する注文
      %{
        user_id: "user_001",
        items: [
          %{product_id: Enum.at(products, 0).id.value, quantity: 1},
          %{product_id: Enum.at(products, 3).id.value, quantity: 2}
        ]
      },
      # 複数商品の注文
      %{
        user_id: "user_002",
        items: [
          %{product_id: Enum.at(products, 1).id.value, quantity: 1},
          %{product_id: Enum.at(products, 4).id.value, quantity: 1},
          %{product_id: Enum.at(products, 7).id.value, quantity: 3}
        ]
      }
    ]
    
    Enum.map(orders_data, fn data ->
      # 商品情報を追加
      items = Enum.map(data.items, fn item ->
        product = Map.get(product_map, item.product_id)
        %{
          product_id: item.product_id,
          product_name: product.name.value,
          quantity: item.quantity,
          unit_price: product.price.amount |> Decimal.to_string()
        }
      end)
      
      command = %{
        __struct__: "CommandService.Application.Commands.OrderCommands.CreateOrder",
        command_type: "order.create",
        user_id: data.user_id,
        items: items,
        metadata: %{}
      }
      
      case RemoteCommandBus.send_command(command) do
        {:ok, result} ->
          total = calculate_total(items)
          IO.puts("  - 注文 #{result.id.value} (ユーザー: #{data.user_id}, 合計: ¥#{total})")
          result
        {:error, reason} ->
          IO.puts("  ❌ 注文の作成に失敗: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.filter(&(&1))
  end
  
  defp calculate_total(items) do
    items
    |> Enum.reduce(Decimal.new(0), fn item, acc ->
      price = Decimal.new(item.unit_price)
      quantity = Decimal.new(item.quantity)
      Decimal.add(acc, Decimal.mult(price, quantity))
    end)
    |> Decimal.to_string()
  end
end

# アプリケーションが起動するまで待機
Process.sleep(2000)

# デモデータを投入
SeedDemoData.run()