defmodule CommandService.Infrastructure.CommandBus do
  @moduledoc """
  コマンドバス - コマンドを適切なハンドラーにルーティングする
  """

  @behaviour Shared.Domain.Saga.CommandDispatcherBehaviour

  alias CommandService.Application.Handlers.{
    OrderCommandHandler,
    CategoryCommandHandler,
    ProductCommandHandler
  }

  @doc """
  コマンドを実行する
  """
  def dispatch(command) do
    # コマンドタイプに基づいて適切なハンドラーを選択
    handler = get_handler(command)

    if handler do
      handler.handle_command(command)
    else
      {:error, :unknown_command}
    end
  end

  # 代替名のためのエイリアス
  def execute(command), do: dispatch(command)

  @doc """
  複数のコマンドを並列実行する
  """
  def dispatch_parallel(commands) when is_list(commands) do
    tasks =
      Enum.map(commands, fn command ->
        Task.async(fn -> dispatch(command) end)
      end)

    Enum.map(tasks, fn task ->
      Task.await(task, :infinity)
    end)
  end

  @doc """
  補償コマンドを実行する（エラーはログに記録するが、エラーを返さない）
  """
  def dispatch_compensation(command) do
    case dispatch(command) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        require Logger

        Logger.error(
          "Compensation command failed: #{inspect(command)}, reason: #{inspect(reason)}"
        )

        {:ok, %{compensated: true, error: reason}}
    end
  end

  defp get_handler(command) do
    # コマンドの型に基づいてハンドラーを選択
    cond do
      is_order_command?(command) -> OrderCommandHandler
      is_category_command?(command) -> CategoryCommandHandler
      is_product_command?(command) -> ProductCommandHandler
      true -> nil
    end
  end

  defp is_order_command?(command) do
    module = command.__struct__

    module in [
      CommandService.Domain.Commands.ReserveInventory,
      CommandService.Domain.Commands.ReleaseInventory,
      CommandService.Domain.Commands.ProcessPayment,
      CommandService.Domain.Commands.RefundPayment,
      CommandService.Domain.Commands.ArrangeShipping,
      CommandService.Domain.Commands.CancelShipping,
      CommandService.Domain.Commands.ConfirmOrder,
      CommandService.Domain.Commands.CancelOrder,
      CommandService.Domain.Commands.Compensations.CancelInventoryReservation,
      CommandService.Domain.Commands.Compensations.RefundPayment,
      CommandService.Domain.Commands.Compensations.CancelShipping,
      # Shared Saga Commands
      Shared.Domain.Saga.Commands.ReserveInventory,
      Shared.Domain.Saga.Commands.ProcessPayment,
      Shared.Domain.Saga.Commands.ArrangeShipping,
      Shared.Domain.Saga.Commands.ConfirmOrder,
      Shared.Domain.Saga.Commands.CancelInventoryReservation,
      Shared.Domain.Saga.Commands.RefundPayment,
      Shared.Domain.Saga.Commands.CancelShipping
    ]
  end

  defp is_category_command?(_command) do
    # TODO: カテゴリコマンドの判定を実装
    false
  end

  defp is_product_command?(_command) do
    # TODO: 商品コマンドの判定を実装
    false
  end
end
