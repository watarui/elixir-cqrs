defmodule CommandService.Application.Commands.SagaCommands.ReleaseInventory do
  @moduledoc """
  在庫解放コマンド
  """

  use CommandService.Application.Commands.BaseCommand

  defstruct [:saga_id, :order_id, :items, :metadata]

  @type t :: %__MODULE__{
          saga_id: String.t(),
          order_id: String.t(),
          items: list(map()),
          metadata: map()
        }

  def new(params) do
    %__MODULE__{
      saga_id: params[:saga_id],
      order_id: params[:order_id],
      items: params[:items] || [],
      metadata: params[:metadata] || %{}
    }
  end

  def validate(command) do
    with :ok <- validate_required(command.saga_id, "saga_id"),
         :ok <- validate_required(command.order_id, "order_id"),
         :ok <- validate_items(command.items) do
      {:ok, command}
    end
  end

  defp validate_items([]), do: {:error, "items cannot be empty"}

  defp validate_items(items) when is_list(items) do
    Enum.reduce(items, :ok, fn item, acc ->
      case acc do
        :ok ->
          with :ok <-
                 validate_required(item["product_id"] || item[:product_id], "product_id in item"),
               :ok <-
                 validate_positive_number(item["quantity"] || item[:quantity], "quantity in item") do
            :ok
          end

        error ->
          error
      end
    end)
  end

  defp validate_items(_), do: {:error, "items must be a list"}

  def command_type, do: "release_inventory"
end
