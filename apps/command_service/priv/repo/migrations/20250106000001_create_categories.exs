defmodule CommandService.Infrastructure.Database.Connection.Migrations.CreateCategories do
  @moduledoc """
  カテゴリテーブル作成マイグレーション
  """

  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:name, :string, null: false)

      timestamps()
    end

    create(unique_index(:categories, [:name]))
  end
end
