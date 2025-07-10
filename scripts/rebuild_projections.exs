#!/usr/bin/env elixir
# プロジェクションを再構築するスクリプト

# Mix の初期化
Mix.start()
Mix.Task.run("app.start")

require Logger

Logger.info("プロジェクションの再構築を開始します...")

# QueryService の ProjectionManager を使ってプロジェクションを再構築
case QueryService.Infrastructure.ProjectionManager.rebuild_all_projections() do
  {:ok, results} ->
    Logger.info("プロジェクションの再構築が完了しました。")
    
    Enum.each(results, fn {projection, result} ->
      case result do
        {:ok, count} ->
          Logger.info("#{projection}: #{count} イベントを処理しました。")
        
        {:error, reason} ->
          Logger.error("#{projection}: エラー - #{inspect(reason)}")
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
    
    # 注文数を確認
    order_count = QueryService.Repo.aggregate("orders", :count, :id)
    Logger.info("注文数: #{order_count}")
    
  {:error, reason} ->
    Logger.error("プロジェクションの再構築に失敗しました: #{inspect(reason)}")
    System.halt(1)
end