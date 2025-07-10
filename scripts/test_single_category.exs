#!/usr/bin/env elixir
# 単一カテゴリ作成テストスクリプト

Mix.start()
Mix.Task.run("app.start")

require Logger

# 単一のカテゴリを作成
alias ClientService.Infrastructure.RemoteCommandBus, as: RemoteCommandBus

Logger.info("単一カテゴリの作成をテストします...")

command = %{
  command_type: "category.create",
  name: "Test Category",
  description: "テストカテゴリ",
  metadata: %{},
  __struct__: "CommandService.Application.Commands.CategoryCommands.CreateCategory"
}

case RemoteCommandBus.send_command(command) do
  {:ok, result} ->
    Logger.info("カテゴリ作成成功: #{inspect(result.id.value)}")
    
    # 少し待機
    Process.sleep(1000)
    
    # QueryServiceのデータを確認
    query_categories = QueryService.Repo.all(QueryService.Infrastructure.Repositories.CategoryRepository.CategorySchema)
    Logger.info("QueryServiceのカテゴリ数: #{length(query_categories)}")
    
    Enum.each(query_categories, fn cat ->
      Logger.info("- #{cat.name} (#{cat.id})")
    end)
    
  {:error, reason} ->
    Logger.error("カテゴリ作成失敗: #{inspect(reason)}")
end