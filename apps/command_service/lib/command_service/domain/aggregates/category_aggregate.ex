defmodule CommandService.Domain.Aggregates.CategoryAggregate do
  @moduledoc """
  カテゴリアグリゲート

  カテゴリの階層構造とビジネスロジックを管理します
  """

  defstruct [
    :id,
    :name,
    :description,
    :parent_id,
    :path,
    :depth,
    :deleted,
    :version,
    :pending_events
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          parent_id: String.t() | nil,
          path: list(String.t()),
          depth: non_neg_integer(),
          deleted: boolean(),
          version: non_neg_integer(),
          pending_events: list(map())
        }

  @max_depth 5

  # 新規作成
  @spec new() :: t()
  def new do
    %__MODULE__{
      id: nil,
      name: nil,
      description: nil,
      parent_id: nil,
      path: [],
      depth: 0,
      deleted: false,
      version: 0,
      pending_events: []
    }
  end

  @spec new(String.t()) :: t()
  def new(id) when is_binary(id) do
    %__MODULE__{new() | id: id}
  end

  # コマンド実行
  @spec execute(t(), tuple()) :: {:ok, list(map())} | {:error, atom() | String.t()}
  def execute(%__MODULE__{id: nil}, {:create_category, params}) do
    # バリデーション
    with :ok <- validate_name(params.name) do
      category_id = params.id || Ecto.UUID.generate()

      # CommandHandlerから渡されたparent_pathを使用
      parent_path = params[:parent_path] || []

      event = %{
        event_type: "category_created",
        aggregate_id: category_id,
        aggregate_type: "category",
        event_data: %{
          name: params.name,
          description: params[:description],
          parent_id: params[:parent_id],
          path: parent_path
        },
        event_metadata: params[:metadata] || %{},
        event_version: 1,
        occurred_at: DateTime.utc_now()
      }

      {:ok, [event]}
    end
  end

  def execute(%__MODULE__{deleted: true}, _command) do
    {:error, :category_not_found}
  end

  def execute(%__MODULE__{id: id} = aggregate, {:update_category, params}) when not is_nil(id) do
    changes = build_update_changes(aggregate, params)

    if map_size(changes) == 0 do
      {:ok, []}
    else
      # 名前変更の場合は重複チェック
      with :ok <- validate_update_name(changes[:name], aggregate),
           :ok <- validate_parent_change(changes[:parent_id], aggregate) do
        events = []

        # 通常の更新イベント
        update_event = %{
          event_type: "category_updated",
          aggregate_id: id,
          aggregate_type: "category",
          event_data: changes,
          event_metadata: params[:metadata] || %{},
          event_version: aggregate.version + 1,
          occurred_at: DateTime.utc_now()
        }

        events = [update_event | events]

        # parent_idが変更された場合は移動イベントも生成
        events =
          if Map.has_key?(changes, :parent_id) do
            # CommandHandlerから渡されたnew_pathを使用
            new_path = params[:new_path] || build_new_path(changes.parent_id)

            move_event = %{
              event_type: "category_moved",
              aggregate_id: id,
              aggregate_type: "category",
              event_data: %{
                old_parent_id: aggregate.parent_id,
                new_parent_id: changes.parent_id,
                old_path: aggregate.path,
                new_path: new_path
              },
              event_metadata: params[:metadata] || %{},
              event_version: aggregate.version + 2,
              occurred_at: DateTime.utc_now()
            }

            [move_event | events]
          else
            events
          end

        {:ok, Enum.reverse(events)}
      end
    end
  end

  def execute(%__MODULE__{id: id} = aggregate, {:delete_category, params}) when not is_nil(id) do
    # サブカテゴリの存在チェック
    with :ok <- check_no_subcategories(id),
         :ok <- check_no_products(id) do
      event = %{
        event_type: "category_deleted",
        aggregate_id: id,
        aggregate_type: "category",
        event_data: %{
          reason: params[:reason]
        },
        event_metadata: params[:metadata] || %{},
        event_version: aggregate.version + 1,
        occurred_at: DateTime.utc_now()
      }

      {:ok, [event]}
    end
  end

  def execute(_aggregate, _command) do
    {:error, :invalid_command}
  end

  # イベントから状態を復元
  @spec load_from_events(list(map())) :: t()
  def load_from_events(events) do
    Enum.reduce(events, new(), &apply_event(&2, &1))
  end

  # イベント適用
  defp apply_event(aggregate, event) do
    case event.event_type do
      "category_created" ->
        %__MODULE__{
          aggregate
          | id: event.aggregate_id,
            name: event.event_data.name,
            description: event.event_data[:description],
            parent_id: event.event_data[:parent_id],
            path: event.event_data[:path] || [],
            depth: length(event.event_data[:path] || []),
            deleted: false,
            version: event.event_version
        }

      "category_updated" ->
        aggregate
        |> maybe_update(:name, event.event_data[:name])
        |> maybe_update(:description, event.event_data[:description])
        |> Map.put(:version, event.event_version)

      "category_moved" ->
        %__MODULE__{
          aggregate
          | parent_id: event.event_data.new_parent_id,
            path: event.event_data.new_path,
            depth: length(event.event_data.new_path),
            version: event.event_version
        }

      "category_deleted" ->
        %__MODULE__{
          aggregate
          | deleted: true,
            version: event.event_version
        }

      _ ->
        aggregate
    end
  end

  defp maybe_update(aggregate, _field, nil), do: aggregate
  defp maybe_update(aggregate, field, value), do: Map.put(aggregate, field, value)

  # バリデーション関数
  defp validate_name(nil), do: {:error, :invalid_name}
  defp validate_name(""), do: {:error, :invalid_name}
  defp validate_name(name) when is_binary(name), do: :ok
  defp validate_name(_), do: {:error, :invalid_name}

  defp validate_duplicate_name(_name, _parent_id, _exclude_id) do
    # CommandHandlerでチェック済み
    :ok
  end

  defp validate_parent_and_get_path(nil), do: {:ok, []}

  defp validate_parent_and_get_path(_parent_id) do
    # CommandHandlerでパス取得済み
    {:ok, []}
  end

  defp validate_update_name(nil, _aggregate), do: :ok

  defp validate_update_name(new_name, aggregate) do
    if new_name != aggregate.name do
      validate_duplicate_name(new_name, aggregate.parent_id, aggregate.id)
    else
      :ok
    end
  end

  defp validate_parent_change(nil, _aggregate), do: :ok

  defp validate_parent_change(new_parent_id, aggregate) do
    cond do
      new_parent_id == aggregate.id ->
        {:error, :circular_reference}

      new_parent_id == aggregate.parent_id ->
        :ok

      true ->
        # CommandHandlerで循環参照チェック済み
        :ok
    end
  end

  defp check_no_subcategories(_category_id) do
    # CommandHandlerでチェック済み
    :ok
  end

  defp check_no_products(_category_id) do
    # CommandHandlerでチェック済み
    :ok
  end

  defp build_update_changes(aggregate, params) do
    changes = %{}

    changes =
      if params[:name] && params[:name] != aggregate.name do
        Map.put(changes, :name, params[:name])
      else
        changes
      end

    changes =
      if Map.has_key?(params, :description) && params[:description] != aggregate.description do
        Map.put(changes, :description, params[:description])
      else
        changes
      end

    changes =
      if Map.has_key?(params, :parent_id) && params[:parent_id] != aggregate.parent_id do
        Map.put(changes, :parent_id, params[:parent_id])
      else
        changes
      end

    changes
  end

  defp build_new_path(nil), do: []

  defp build_new_path(_parent_id) do
    # CommandHandlerでnew_pathが渡されることを想定
    []
  end
end
