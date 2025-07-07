defmodule CommandService.Application.Services.CategoryService do
  @moduledoc """
  カテゴリアプリケーションサービス

  カテゴリに関するビジネスロジックとオーケストレーションを提供します
  """

  alias CommandService.Domain.Entities.Category
  alias CommandService.Infrastructure.Repositories.CategoryRepository, as: CategoryRepo
  alias Shared.Errors.AppError

  # デフォルトのリポジトリ実装
  @default_repo CategoryRepo

  @spec create_category(map(), module()) :: {:ok, Category.t()} | {:error, String.t() | AppError.t()}
  def create_category(params, repo \\ @default_repo) do
    id = UUID.uuid4()
    name = params[:name]

    # 既存チェック
    case repo.exists?(id) do
      true ->
        {:error, "Category with ID #{id} already exists"}

      false ->
        # カテゴリエンティティの作成
        with {:ok, category} <- Category.new(id, name),
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
  end

  @spec get_category(String.t(), module()) :: {:ok, Category.t()} | {:error, :not_found | String.t() | AppError.t()}
  def get_category(id, repo \\ @default_repo) do
    repo.find_by_id(id)
  end

  @spec update_category(String.t(), map(), module()) :: {:ok, Category.t()} | {:error, String.t() | AppError.t()}
  def update_category(id, params, repo \\ @default_repo) do
    with {:ok, category} <- repo.find_by_id(id),
         {:ok, updated_category} <- Category.update(category, params),
         {:ok, saved_category} <- repo.update(updated_category) do
      {:ok, saved_category}
    end
  end

  @spec delete_category(String.t(), module()) :: :ok | {:error, String.t() | AppError.t()}
  def delete_category(id, repo \\ @default_repo) do
    # 商品が存在する場合は削除を拒否
    case has_products?(id, repo) do
      true ->
        {:error, "Cannot delete category with existing products"}

      false ->
        repo.delete(id)
    end
  end

  @spec list_categories(module()) :: {:ok, [Category.t()]} | {:error, String.t() | AppError.t()}
  def list_categories(repo \\ @default_repo) do
    repo.list()
  end

  @spec category_exists?(String.t(), module()) :: boolean()
  def category_exists?(id, repo \\ @default_repo) do
    repo.exists?(id)
  end

  # プライベート関数 - カテゴリに商品が存在するかチェック
  defp has_products?(_category_id, _repo) do
    # ProductRepositoryを使用して商品の存在をチェック
    # 実装簡略化のため、falseを返す
    false
  end
end
