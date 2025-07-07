defmodule CommandService.Application.Services.CategoryService do
  @moduledoc """
  カテゴリアプリケーションサービス

  カテゴリに関するビジネスロジックとオーケストレーションを提供します
  """

  alias CommandService.Domain.Entities.Category
  alias CommandService.Domain.Logic.CategoryLogic
  alias CommandService.Infrastructure.Repositories.CategoryRepository, as: CategoryRepo
  alias Shared.Errors.AppError

  # デフォルトのリポジトリ実装
  @default_repo CategoryRepo

  @spec create_category(map(), module()) ::
          {:ok, Category.t()} | {:error, String.t() | AppError.t()}
  def create_category(params, repo \\ @default_repo) do
    id = UUID.uuid4()
    name = params[:name]

    # 純粋な関数でカテゴリ名を検証
    with :ok <- CategoryLogic.validate_category_name(name || ""),
         # 既存チェック
         false <- repo.exists?(id) || {:error, "Category with ID #{id} already exists"},
         # カテゴリエンティティの作成
         {:ok, category} <- Category.new(id, name),
         {:ok, saved_category} <- repo.save(category) do
      # イベントログ記録
      Shared.EventLogger.log_domain_event(%Shared.Events.CategoryCreated{
        id: saved_category.id,
        name: saved_category.name,
        timestamp: DateTime.utc_now()
      })

      {:ok, saved_category}
    end
  end

  @spec get_category(String.t(), module()) ::
          {:ok, Category.t()} | {:error, :not_found | String.t() | AppError.t()}
  def get_category(id, repo \\ @default_repo) do
    repo.find_by_id(id)
  end

  @spec update_category(String.t(), map(), module()) ::
          {:ok, Category.t()} | {:error, String.t() | AppError.t()}
  def update_category(id, params, repo \\ @default_repo) do
    with {:ok, category} <- repo.find_by_id(id),
         # 純粋な関数でパラメータを検証
         :ok <- validate_update_params(params),
         {:ok, updated_category} <- Category.update(category, params),
         {:ok, saved_category} <- repo.update(updated_category) do
      # 変更検出（ピュア関数）
      changes = CategoryLogic.detect_changes(category, saved_category)
      log_category_changes(id, changes)

      {:ok, saved_category}
    end
  end

  # 純粋な検証関数
  defp validate_update_params(params) do
    case params[:name] do
      nil -> :ok
      "" -> :ok
      name -> CategoryLogic.validate_category_name(name)
    end
  end

  # 変更ログ記録（副作用）
  defp log_category_changes(_id, %{changes: changes}) when map_size(changes) > 0 do
    # ログ記録の実装（将来的に追加）
    :ok
  end

  defp log_category_changes(_id, _), do: :ok

  @spec delete_category(String.t(), module()) :: :ok | {:error, String.t() | AppError.t()}
  def delete_category(id, repo \\ @default_repo) do
    # 商品が存在する場合は削除を拒否
    if has_products?(id, repo) do
      {:error, "Cannot delete category with existing products"}
    else
      repo.delete(id)
    end
  end

  @spec list_categories(module()) :: {:ok, [Category.t()]} | {:error, String.t() | AppError.t()}
  def list_categories(repo \\ @default_repo) do
    with {:ok, categories} <- repo.list() do
      # 純粋な関数でソート
      sorted_categories = CategoryLogic.sort_alphabetically(categories)
      {:ok, sorted_categories}
    end
  end

  @spec category_exists?(String.t(), module()) :: boolean()
  def category_exists?(id, repo \\ @default_repo) do
    repo.exists?(id)
  end

  # プライベート関数 - カテゴリに商品が存在するかチェック
  defp has_products?(category_id, _repo) do
    # ProductRepositoryを使用して商品の存在をチェック
    alias CommandService.Infrastructure.Repositories.ProductRepository

    case ProductRepository.find_by_category_id(category_id) do
      {:ok, []} -> false
      {:ok, _products} -> true
      {:error, _} -> false
    end
  end
end
