defmodule Shared.Infrastructure.EventStore.Repo.Migrations.CreateDeadLetters do
  use Ecto.Migration

  def change do
    create table(:dead_letters, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :source, :string, null: false
      add :message, :text, null: false
      add :error_message, :text, null: false
      add :error_details, :map
      add :metadata, :map
      add :status, :string, null: false, default: "pending"
      add :reprocessed_at, :utc_datetime
      add :reprocess_result, :text

      timestamps()
    end

    create index(:dead_letters, [:source])
    create index(:dead_letters, [:status])
    create index(:dead_letters, [:created_at])
  end
end