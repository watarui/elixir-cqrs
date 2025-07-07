defmodule CommandService.Infrastructure.CommandBus do
  @moduledoc """
  コマンドバス - コマンドを適切なハンドラーにルーティングする
  """
  
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
      CommandService.Domain.Commands.CancelOrder
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