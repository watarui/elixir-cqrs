defmodule ClientService.GraphQL.Resolvers.MonitoringResolver do
  @moduledoc """
  監視用クエリのリゾルバー
  """

  alias Shared.Infrastructure.EventStore.Schema.Event
  alias QueryService.Domain.ReadModels.{Category, Product, Order}
  import Ecto.Query

  @doc """
  イベントストアの統計情報を取得
  """
  def get_event_store_stats(_parent, _args, _resolution) do
    # 総イベント数
    total_events = Shared.Infrastructure.EventStore.Repo.aggregate(Event, :count)

    # イベントタイプ別の集計
    events_by_type =
      Event
      |> group_by(:event_type)
      |> select([e], %{event_type: e.event_type, count: count(e.id)})
      |> Shared.Infrastructure.EventStore.Repo.all()

    # アグリゲートタイプ別の集計
    events_by_aggregate =
      Event
      |> group_by(:aggregate_type)
      |> select([e], %{aggregate_type: e.aggregate_type, count: count(e.id)})
      |> Shared.Infrastructure.EventStore.Repo.all()

    # 最新のシーケンス番号
    latest_sequence =
      Event
      |> select([e], max(e.global_sequence))
      |> Shared.Infrastructure.EventStore.Repo.one()

    {:ok,
     %{
       total_events: total_events || 0,
       events_by_type: events_by_type,
       events_by_aggregate: events_by_aggregate,
       latest_sequence: latest_sequence
     }}
  end

  @doc """
  イベント一覧を取得
  """
  def list_events(_parent, args, _resolution) do
    query = from(e in Event)

    query =
      if args[:aggregate_id] do
        from(e in query, where: e.aggregate_id == ^args.aggregate_id)
      else
        query
      end

    query =
      if args[:aggregate_type] do
        from(e in query, where: e.aggregate_type == ^args.aggregate_type)
      else
        query
      end

    query =
      if args[:event_type] do
        from(e in query, where: e.event_type == ^args.event_type)
      else
        query
      end

    query =
      if args[:after_id] do
        from(e in query, where: e.id > ^args.after_id)
      else
        query
      end

    events =
      query
      |> order_by(desc: :id)
      |> limit(^(args[:limit] || 100))
      |> Shared.Infrastructure.EventStore.Repo.all()

    {:ok, events}
  end

  @doc """
  最新のイベントを取得
  """
  def recent_events(_parent, args, _resolution) do
    limit = args[:limit] || 50

    events =
      Event
      |> order_by(desc: :id)
      |> limit(^limit)
      |> Shared.Infrastructure.EventStore.Repo.all()

    {:ok, events}
  end

  @doc """
  システム統計を取得
  """
  def get_system_statistics(_parent, _args, _resolution) do
    # Event Store の統計
    event_store_count = Shared.Infrastructure.EventStore.Repo.aggregate(Event, :count) || 0

    # Command DB の統計（カテゴリと商品のみ）
    categories_cmd_count = get_command_count("categories")
    products_cmd_count = get_command_count("products")
    command_db_count = categories_cmd_count + products_cmd_count

    # Query DB の統計
    categories_count = get_query_count(Category)
    products_count = get_query_count(Product)
    orders_count = get_query_count(Order)

    # SAGA の統計
    saga_stats = get_saga_stats()

    {:ok,
     %{
       event_store: %{
         total_records: event_store_count,
         last_updated: DateTime.utc_now()
       },
       command_db: %{
         total_records: command_db_count,
         last_updated: DateTime.utc_now()
       },
       query_db: %{
         categories: categories_count,
         products: products_count,
         orders: orders_count,
         last_updated: DateTime.utc_now()
       },
       sagas: saga_stats
     }}
  end

  @doc """
  プロジェクションの状態を取得
  """
  def get_projection_status(_parent, _args, _resolution) do
    # Query Service のプロジェクションマネージャーから状態を取得
    case :rpc.call(:"query@127.0.0.1", QueryService.Infrastructure.ProjectionManager, :get_status, []) do
      {:badrpc, _reason} ->
        {:error, "Query Service に接続できません"}

      status when is_map(status) ->
        projections =
          Enum.map(status, fn {module, info} ->
            %{
              name: inspect(module),
              status: to_string(info.status),
              last_error: info.last_error,
              processed_count: info.processed_count
            }
          end)

        {:ok, projections}

      _ ->
        {:error, "プロジェクションの状態を取得できません"}
    end
  end

  # Private functions

  defp get_query_count(module) do
    try do
      # Query Service の Repo を使用
      case :rpc.call(:"query@127.0.0.1", QueryService.Repo, :aggregate, [module, :count]) do
        {:badrpc, _} -> 0
        count when is_integer(count) -> count
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end

  defp get_command_count(table_name) do
    try do
      # Command Service の Repo を使用
      query = "SELECT COUNT(*) FROM #{table_name}"
      case :rpc.call(:"command@127.0.0.1", CommandService.Repo, :query, [query]) do
        {:badrpc, _} -> 0
        {:ok, %{rows: [[count]]}} -> count || 0
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end

  defp get_saga_stats do
    try do
      # SAGA テーブルから統計を取得
      query = """
      SELECT 
        COUNT(*) FILTER (WHERE status = 'started') as active,
        COUNT(*) FILTER (WHERE status = 'completed') as completed,
        COUNT(*) FILTER (WHERE status = 'failed') as failed,
        COUNT(*) FILTER (WHERE status = 'compensated') as compensated,
        COUNT(*) as total
      FROM sagas
      """

      case Shared.Infrastructure.EventStore.Repo.query(query) do
        {:ok, %{rows: [[active, completed, failed, compensated, total]]}} ->
          %{
            active: active || 0,
            completed: completed || 0,
            failed: failed || 0,
            compensated: compensated || 0,
            total: total || 0
          }

        _ ->
          %{active: 0, completed: 0, failed: 0, compensated: 0, total: 0}
      end
    rescue
      _ ->
        %{active: 0, completed: 0, failed: 0, compensated: 0, total: 0}
    end
  end
end