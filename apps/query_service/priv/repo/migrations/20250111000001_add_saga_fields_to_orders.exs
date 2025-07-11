defmodule QueryService.Repo.Migrations.AddSagaFieldsToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :saga_id, :string
      add :saga_status, :string
      add :saga_current_step, :string
    end

    create index(:orders, [:saga_id])
    create index(:orders, [:saga_status])
  end
end