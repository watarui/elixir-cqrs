defmodule Shared.Repo.Migrations.CreateArchivedEventsTable do
  use Ecto.Migration

  def change do
    # アーカイブイベントテーブルの作成
    create table(:archived_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :aggregate_id, :binary_id, null: false
      add :aggregate_type, :string, null: false
      add :event_type, :string, null: false
      add :event_version, :integer, null: false
      add :event_data, :map, null: false
      add :metadata, :map, default: %{}
      add :event_timestamp, :utc_datetime_usec, null: false
      add :archived_at, :utc_datetime_usec, null: false
      
      timestamps(type: :utc_datetime_usec)
    end
    
    # インデックスの作成
    create index(:archived_events, [:aggregate_id])
    create index(:archived_events, [:event_type])
    create index(:archived_events, [:event_timestamp])
    create index(:archived_events, [:archived_at])
    
    # 複合インデックス
    create index(:archived_events, [:aggregate_id, :event_version])
    create index(:archived_events, [:aggregate_type, :event_timestamp])
  end
end