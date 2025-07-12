defmodule ClientService.GraphQL.Types.Monitoring do
  @moduledoc """
  監視用の GraphQL タイプ定義
  """

  use Absinthe.Schema.Notation

  @desc "イベントストアの統計情報"
  object :event_store_stats do
    field :total_events, non_null(:integer)
    field :events_by_type, list_of(:event_type_count)
    field :events_by_aggregate, list_of(:aggregate_type_count)
    field :latest_sequence, :integer
  end

  @desc "イベントタイプ別のカウント"
  object :event_type_count do
    field :event_type, non_null(:string)
    field :count, non_null(:integer)
  end

  @desc "アグリゲートタイプ別のカウント"
  object :aggregate_type_count do
    field :aggregate_type, non_null(:string)
    field :count, non_null(:integer)
  end

  @desc "イベント"
  object :event do
    field :id, non_null(:integer)
    field :aggregate_id, non_null(:id)
    field :aggregate_type, non_null(:string)
    field :event_type, non_null(:string)
    field :event_data, :json
    field :event_version, non_null(:integer)
    field :global_sequence, :integer
    field :metadata, :json
    field :inserted_at, non_null(:datetime)
  end

  @desc "システム統計"
  object :system_statistics do
    field :event_store, non_null(:database_stats)
    field :command_db, non_null(:database_stats)
    field :query_db, non_null(:read_model_stats)
    field :sagas, non_null(:saga_stats)
  end

  @desc "データベース統計"
  object :database_stats do
    field :total_records, non_null(:integer)
    field :last_updated, :datetime
  end

  @desc "読み取りモデル統計"
  object :read_model_stats do
    field :categories, non_null(:integer)
    field :products, non_null(:integer)
    field :orders, non_null(:integer)
    field :last_updated, :datetime
  end

  @desc "SAGA統計"
  object :saga_stats do
    field :active, non_null(:integer)
    field :completed, non_null(:integer)
    field :failed, non_null(:integer)
    field :compensated, non_null(:integer)
    field :total, non_null(:integer)
  end

  @desc "プロジェクションの状態"
  object :projection_status do
    field :name, non_null(:string)
    field :status, non_null(:string)
    field :last_error, :string
    field :processed_count, non_null(:integer)
  end
end