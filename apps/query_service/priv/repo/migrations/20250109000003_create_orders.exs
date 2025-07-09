defmodule QueryService.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, :uuid, null: false
      add :order_number, :string, null: false
      add :status, :string, null: false
      add :total_amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "JPY", null: false
      add :items, :jsonb, default: "[]", null: false
      add :shipping_address, :map
      add :payment_method, :string
      add :payment_status, :string
      add :shipping_status, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:orders, [:user_id])
    create index(:orders, [:status])
    create index(:orders, [:inserted_at])
    create unique_index(:orders, [:order_number])
  end
end