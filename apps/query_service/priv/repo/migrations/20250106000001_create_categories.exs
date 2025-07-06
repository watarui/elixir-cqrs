defmodule QueryService.Infrastructure.Database.Repo.Migrations.CreateCategories do
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
