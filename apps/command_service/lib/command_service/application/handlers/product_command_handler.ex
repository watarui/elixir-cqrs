defmodule CommandService.Application.Handlers.ProductCommandHandler do
  @moduledoc """
  商品コマンドハンドラー

  商品に関するコマンドを処理し、アグリゲートにイベントを適用します
  """

  @behaviour CommandService.Application.Handlers.CommandHandler

  alias CommandService.Domain.Aggregates.ProductAggregate

  alias CommandService.Application.Commands.ProductCommands.{
    CreateProduct,
    DeleteProduct,
    UpdateProduct
  }

  alias Shared.Infrastructure.EventStore

  @impl true
  def command_types do
    [CreateProduct, UpdateProduct, DeleteProduct]
  end

  @impl true
  def handle_command(%CreateProduct{} = command) do
    with :ok <- command.__struct__.validate(command),
         aggregate = ProductAggregate.new(),
         {:ok, events} <-
           ProductAggregate.execute(aggregate, {:create_product, Map.from_struct(command)}),
         {:ok, _version} <- EventStore.save_aggregate_events(command.id, events, 0) do
      # イベントをログに記録
      Enum.each(events, &Shared.EventLogger.log_domain_event/1)

      # イベントバスに発行
      Enum.each(events, &Shared.Infrastructure.EventBus.publish/1)

      {:ok, %{aggregate_id: command.id, events: events}}
    end
  end

  def handle_command(%UpdateProduct{} = command) do
    with :ok <- command.__struct__.validate(command),
         {:ok, events} <- EventStore.read_aggregate_events(command.id),
         aggregate = ProductAggregate.load_from_events(events),
         {:ok, new_events} <-
           ProductAggregate.execute(aggregate, {:update_product, Map.from_struct(command)}),
         {:ok, _version} <-
           EventStore.save_aggregate_events(command.id, new_events, aggregate.version) do
      # イベントをログに記録
      Enum.each(new_events, &Shared.EventLogger.log_domain_event/1)

      # イベントバスに発行
      Enum.each(new_events, &Shared.Infrastructure.EventBus.publish/1)

      {:ok, %{aggregate_id: command.id, events: new_events}}
    else
      {:error, :not_found} -> {:error, "Product not found"}
      error -> error
    end
  end

  def handle_command(%DeleteProduct{} = command) do
    with :ok <- command.__struct__.validate(command),
         {:ok, events} <- EventStore.read_aggregate_events(command.id),
         aggregate = ProductAggregate.load_from_events(events),
         {:ok, new_events} <-
           ProductAggregate.execute(aggregate, {:delete_product, Map.from_struct(command)}),
         {:ok, _version} <-
           EventStore.save_aggregate_events(command.id, new_events, aggregate.version) do
      # イベントをログに記録
      Enum.each(new_events, &Shared.EventLogger.log_domain_event/1)

      # イベントバスに発行
      Enum.each(new_events, &Shared.Infrastructure.EventBus.publish/1)

      {:ok, %{aggregate_id: command.id, events: new_events}}
    else
      {:error, :not_found} -> {:error, "Product not found"}
      error -> error
    end
  end

  def handle_command(_command) do
    {:error, "Unknown command"}
  end
end
