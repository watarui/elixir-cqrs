# Command Service gRPCサーバーテストスクリプト

# Repositoryテスト
alias CommandService.Infrastructure.Repositories.CategoryRepository
alias CommandService.Application.Services.CategoryService
alias CommandService.Domain.Entities.Category

IO.puts("🔄 Command Service CategoryRepositoryテスト開始...")

case CategoryRepository.list() do
  {:ok, categories} ->
    IO.puts("✅ Repository: #{length(categories)}件のカテゴリ取得成功")

    Enum.each(categories, fn category ->
      IO.puts("  - ID: #{Category.id(category)}, Name: #{Category.name(category)}")
      IO.puts("    Created: #{category.created_at}, Updated: #{category.updated_at}")
    end)

  {:error, reason} ->
    IO.puts("❌ Repository エラー: #{inspect(reason)}")
end

IO.puts("\n🔄 Command Service CategoryServiceテスト開始...")

# 新しいカテゴリを作成してテスト
test_category_name = "テストカテゴリ_#{System.unique_integer([:positive])}"

case CategoryService.create_category(%{name: test_category_name}) do
  {:ok, category} ->
    IO.puts("✅ CategoryService: カテゴリ作成成功")
    IO.puts("  - ID: #{Category.id(category)}, Name: #{Category.name(category)}")
    IO.puts("  - Created: #{category.created_at}, Updated: #{category.updated_at}")

    # 作成したカテゴリを削除
    case CategoryService.delete_category(Category.id(category)) do
      :ok ->
        IO.puts("✅ CategoryService: カテゴリ削除成功")

      {:error, reason} ->
        IO.puts("❌ CategoryService 削除エラー: #{inspect(reason)}")
    end

  {:error, reason} ->
    IO.puts("❌ CategoryService 作成エラー: #{inspect(reason)}")
end

IO.puts("\n🎯 Command Service テスト完了!")
