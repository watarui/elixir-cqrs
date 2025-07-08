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

  @impl true
  def command_types do
    [CreateCategory, UpdateCategory, DeleteCategory]
  end

  @impl true
  def handle_command(%CreateCategory{} = command) do
    with :ok <- command.__struct__.validate(command),
         aggregate = CategoryAggregate.new(),
         {:ok, events} <-
           CategoryAggregate.execute(aggregate, {:create_category, Map.from_struct(command)}),
         {:ok, _version} <- EventStore.save_aggregate_events(command.id, events, 0) do
      # イベントをログに記録
      Enum.each(events, &Shared.EventLogger.log_domain_event/1)

      # イベントバスに発行
      Enum.each(events, &EventBus.publish/1)

      {:ok, %{aggregate_id: command.id, events: events}}
    end
  end

  def handle_command(%UpdateCategory{} = command) do
    with :ok <- command.__struct__.validate(command),
         {:ok, events} <- EventStore.read_aggregate_events(command.id),
         aggregate = CategoryAggregate.load_from_events(events),
         {:ok, new_events} <-
           CategoryAggregate.execute(aggregate, {:update_category, Map.from_struct(command)}),
         {:ok, _version} <-
           EventStore.save_aggregate_events(command.id, new_events, aggregate.version) do
      # イベントをログに記録
      Enum.each(new_events, &Shared.EventLogger.log_domain_event/1)

      # イベントバスに発行
      Enum.each(new_events, &EventBus.publish/1)

      {:ok, %{aggregate_id: command.id, events: new_events}}
    else
      {:error, :not_found} -> {:error, "Category not found"}
      error -> error
    end
  end

  def handle_command(%DeleteCategory{} = command) do
    with :ok <- command.__struct__.validate(command),
         {:ok, events} <- EventStore.read_aggregate_events(command.id),
         aggregate = CategoryAggregate.load_from_events(events),
         {:ok, new_events} <-
           CategoryAggregate.execute(aggregate, {:delete_category, Map.from_struct(command)}),
         {:ok, _version} <-
           EventStore.save_aggregate_events(command.id, new_events, aggregate.version) do
      # イベントをログに記録
      Enum.each(new_events, &Shared.EventLogger.log_domain_event/1)

      # イベントバスに発行
      Enum.each(new_events, &EventBus.publish/1)

      {:ok, %{aggregate_id: command.id, events: new_events}}
    else
      {:error, :not_found} -> {:error, "Category not found"}
      error -> error
    end
  end

  def handle_command(_command) do
    {:error, "Unknown command"}
  end
end
