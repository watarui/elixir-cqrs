#!/usr/bin/env elixir
# リアルタイムプロジェクションのテストスクリプト

Mix.start()
Mix.Task.run("app.start")

require Logger

# 単一のカテゴリを作成
alias ClientService.Infrastructure.RemoteCommandBus, as: RemoteCommandBus

Logger.info("リアルタイムプロジェクションのテストを開始します...")

# 作成前のカテゴリ数を確認
before_count = QueryService.Repo.aggregate("categories", :count, :id)
Logger.info("作成前のカテゴリ数: #{before_count}")

command = %{
  command_type: "category.create",
  name: "Realtime Test Category",
  description: "リアルタイムプロジェクションのテスト",
  metadata: %{},
  __struct__: "CommandService.Application.Commands.CategoryCommands.CreateCategory"
}

case RemoteCommandBus.send_command(command) do
  {:ok, result} ->
    Logger.info("カテゴリ作成成功: #{inspect(result.id.value)}")
    
    # 少し待機してプロジェクションが処理されるのを待つ
    Process.sleep(2000)
    
    # QueryServiceのデータを確認
    after_count = QueryService.Repo.aggregate("categories", :count, :id)
    Logger.info("作成後のカテゴリ数: #{after_count}")
    
    if after_count > before_count do
      Logger.info("✅ リアルタイムプロジェクションが正常に動作しています！")
      
      # 新しく作成されたカテゴリを確認
      case QueryService.Infrastructure.Repositories.CategoryRepository.get(result.id.value) do
        {:ok, category} ->
          Logger.info("作成されたカテゴリ: #{category.name} (#{category.id})")
        {:error, _} ->
          Logger.error("❌ カテゴリが QueryService で見つかりません")
      end
    else
      Logger.error("❌ リアルタイムプロジェクションが動作していません")
    end
    
  {:error, reason} ->
    Logger.error("カテゴリ作成失敗: #{inspect(reason)}")
end