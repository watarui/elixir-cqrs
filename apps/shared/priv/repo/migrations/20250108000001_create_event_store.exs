defmodule Shared.Infrastructure.Database.Repo.Migrations.CreateEventStore do
  use Ecto.Migration

  def change do
    create table(:events, primary_key: false) do
      add :event_id, :binary_id, primary_key: true
      add :aggregate_id, :string, null: false
      add :aggregate_type, :string, null: false
      add :event_type, :string, null: false
      add :event_version, :integer, null: false
      add :event_data, :map, null: false
      add :event_metadata, :map
      add :occurred_at, :utc_datetime_usec, null: false
      
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:events, [:aggregate_id])
    create index(:events, [:aggregate_type])
    create index(:events, [:event_type])
    create index(:events, [:occurred_at])
    create unique_index(:events, [:aggregate_id, :event_version])
  end
end