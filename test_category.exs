
# カテゴリ作成をテスト
alias CommandService.Application.Commands.CategoryCommands.CreateCategory
alias CommandService.Application.Handlers.CategoryHandler

command = %CreateCategory{
  name: "Test Category",
  description: "Test Description"
}

result = CategoryHandler.handle(command)
IO.inspect(result)

