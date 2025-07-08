defmodule QueryService.Infrastructure.Database.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :customer_id, :binary_id, null: false
      add :status, :string, null: false
      add :items, {:array, :map}, default: []
      add :subtotal, :decimal, precision: 10, scale: 2
      add :tax_amount, :decimal, precision: 10, scale: 2
      add :shipping_cost, :decimal, precision: 10, scale: 2
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :shipping_address, :map
      add :payment_status, :string
      add :saga_state, :map

      timestamps()
    end

    create index(:orders, [:customer_id])
    create index(:orders, [:status])
    create index(:orders, [:inserted_at])
  end
end