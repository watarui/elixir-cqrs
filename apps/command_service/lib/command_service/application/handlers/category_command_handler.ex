defmodule CommandService.Application.Handlers.CategoryCommandHandler do
  @moduledoc """
  カテゴリコマンドハンドラー

  カテゴリに関するコマンドを処理し、アグリゲートにイベントを適用します
  """

  @behaviour CommandService.Application.Handlers.CommandHandler

  alias CommandService.Domain.Aggregates.CategoryAggregate

  alias CommandService.Application.Commands.CategoryCommands.{
    CreateCategory,
    DeleteCategory,
    UpdateCategory
  }

  alias Shared.Infrastructure.{EventBus, EventStore}
  alias CommandService.Infrastructure.Projections.CategoryProjection

  @impl true
  def command_types do
    [CreateCategory, UpdateCategory, DeleteCategory]
  end

  @impl true
  def handle_command(%CreateCategory{} = command) do
    with :ok <- command.__struct__.validate(command),
         :ok <- check_duplicate_name(command.name, command.parent_id, nil),
         {:ok, parent_path} <- get_parent_path(command.parent_id),
         :ok <- check_depth_limit(parent_path) do
      # コマンドにパス情報を追加
      command_with_path = Map.from_struct(command) |> Map.put(:parent_path, parent_path)

      aggregate = CategoryAggregate.new()

      case CategoryAggregate.execute(aggregate, {:create_category, command_with_path}) do
        {:ok, events} ->
          case EventStore.save_aggregate_events(command.id, events, 0) do
            {:ok, _version} ->
              # イベントをログに記録
              Enum.each(events, &Shared.EventLogger.log_domain_event/1)

              # イベントバスに発行
              Enum.each(events, &EventBus.publish/1)

              {:ok, events}

            error ->
              error
          end

        error ->
          error
      end
    end
  end

  def handle_command(%UpdateCategory{} = command) do
    with :ok <- command.__struct__.validate(command),
         {:ok, events} <- EventStore.read_aggregate_events(command.id) do
      aggregate = CategoryAggregate.load_from_events(events)

      # 削除済みチェック
      if aggregate.deleted do
        {:error, :category_not_found}
      else
        # 名前変更の場合は重複チェック
        with :ok <- check_update_name(command.name, aggregate),
             :ok <- check_parent_change(command.parent_id, aggregate) do
          command_map = Map.from_struct(command)

          # parent_id変更の場合は新しいパスを取得
          command_map =
            if command.parent_id && command.parent_id != aggregate.parent_id do
              case get_parent_path(command.parent_id) do
                {:ok, new_path} -> Map.put(command_map, :new_path, new_path)
                _ -> command_map
              end
            else
              command_map
            end

          case CategoryAggregate.execute(aggregate, {:update_category, command_map}) do
            {:ok, new_events} ->
              case EventStore.save_aggregate_events(command.id, new_events, aggregate.version) do
                {:ok, _version} ->
                  # イベントをログに記録
                  Enum.each(new_events, &Shared.EventLogger.log_domain_event/1)

                  # イベントバスに発行
                  Enum.each(new_events, &EventBus.publish/1)

                  {:ok, new_events}

                error ->
                  error
              end

            error ->
              error
          end
        end
      end
    else
      {:error, :not_found} -> {:error, :category_not_found}
      error -> error
    end
  end

  def handle_command(%DeleteCategory{} = command) do
    with :ok <- command.__struct__.validate(command),
         {:ok, events} <- EventStore.read_aggregate_events(command.id) do
      aggregate = CategoryAggregate.load_from_events(events)

      # 削除済みチェック
      if aggregate.deleted do
        {:error, :category_not_found}
      else
        # サブカテゴリと商品の存在チェック
        with :ok <- check_no_subcategories(command.id),
             :ok <- check_no_products(command.id) do
          case CategoryAggregate.execute(aggregate, {:delete_category, Map.from_struct(command)}) do
            {:ok, new_events} ->
              case EventStore.save_aggregate_events(command.id, new_events, aggregate.version) do
                {:ok, _version} ->
                  # イベントをログに記録
                  Enum.each(new_events, &Shared.EventLogger.log_domain_event/1)

                  # イベントバスに発行
                  Enum.each(new_events, &EventBus.publish/1)

                  {:ok, new_events}

                error ->
                  error
              end

            error ->
              error
          end
        end
      end
    else
      {:error, :not_found} -> {:error, :category_not_found}
      error -> error
    end
  end

  def handle_command(_command) do
    {:error, "Unknown command"}
  end

  # ヘルパー関数

  defp check_duplicate_name(name, parent_id, exclude_id) do
    # 実際の実装では、プロジェクションやリードモデルを使用
    # ここでは簡易実装として、CategoryProjectionを使用
    case CategoryProjection.find_by_name_and_parent(name, parent_id) do
      nil ->
        :ok

      category ->
        if exclude_id && category.id == exclude_id do
          :ok
        else
          {:error, :duplicate_name}
        end
    end
  rescue
    # プロジェクションが存在しない場合は通す
    _ -> :ok
  end

  defp get_parent_path(nil), do: {:ok, []}

  defp get_parent_path(parent_id) do
    # 実際の実装では、プロジェクションから親カテゴリの情報を取得
    case CategoryProjection.get_by_id(parent_id) do
      nil ->
        {:error, :parent_not_found}

      parent ->
        path = (parent.path || []) ++ [parent_id]
        {:ok, path}
    end
  rescue
    # プロジェクションが存在しない場合は親IDのみ
    _ -> {:ok, [parent_id]}
  end

  defp check_depth_limit(parent_path) do
    if length(parent_path) >= 5 do
      {:error, :max_depth_exceeded}
    else
      :ok
    end
  end

  defp check_update_name(nil, _aggregate), do: :ok

  defp check_update_name(new_name, aggregate) do
    if new_name != aggregate.name do
      check_duplicate_name(new_name, aggregate.parent_id, aggregate.id)
    else
      :ok
    end
  end

  defp check_parent_change(nil, _aggregate), do: :ok

  defp check_parent_change(new_parent_id, aggregate) do
    cond do
      new_parent_id == aggregate.id ->
        {:error, :circular_reference}

      new_parent_id == aggregate.parent_id ->
        :ok

      true ->
        # 循環参照チェック（子孫への移動防止）
        case check_circular_reference(new_parent_id, aggregate.id) do
          :ok -> :ok
          error -> error
        end
    end
  end

  defp check_circular_reference(new_parent_id, category_id) do
    # 実際の実装では、新しい親が現在のカテゴリの子孫でないかチェック
    case CategoryProjection.descendant_of?(new_parent_id, category_id) do
      true -> {:error, :circular_reference}
      false -> :ok
    end
  rescue
    # プロジェクションが存在しない場合は通す
    _ -> :ok
  end

  defp check_no_subcategories(category_id) do
    # 実際の実装では、プロジェクションを使用してサブカテゴリの存在をチェック
    case CategoryProjection.has_subcategories?(category_id) do
      true -> {:error, :has_subcategories}
      false -> :ok
    end
  rescue
    # プロジェクションが存在しない場合は通す
    _ -> :ok
  end

  defp check_no_products(category_id) do
    # 実際の実装では、ProductProjectionを使用して商品の存在をチェック
    # ここでは簡易実装として常にOKを返す
    :ok
  end
end
