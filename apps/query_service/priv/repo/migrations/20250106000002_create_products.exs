defmodule QueryService.Infrastructure.Database.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:name, :string, null: false)
      add(:price, :decimal, precision: 10, scale: 2, null: false)

      add(:category_id, references(:categories, type: :string, on_delete: :delete_all),
        null: false
      )

      timestamps()
    end

    create(index(:products, [:category_id]))
    create(index(:products, [:name]))
    create(index(:products, [:price]))
  end
end
