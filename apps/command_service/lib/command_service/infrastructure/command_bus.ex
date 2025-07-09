defmodule CommandService.Infrastructure.CommandBus do
  @moduledoc """
  コマンドバスの実装
  
  コマンドを適切なハンドラーにルーティングして実行します
  """

  use GenServer

  alias CommandService.Application.Handlers.{
    CategoryCommandHandler,
    ProductCommandHandler,
    OrderCommandHandler,
    SagaCommandHandler
  }
  alias Shared.Telemetry.Span

  require Logger

  @type command :: struct()
  @type result :: {:ok, any()} | {:error, String.t()}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  コマンドを実行する
  """
  @spec dispatch(command()) :: result()
  def dispatch(command) do
    GenServer.call(__MODULE__, {:dispatch, command})
  end

  @doc """
  コマンドを非同期で実行する（サガ用）
  """
  @spec dispatch_async(command()) :: :ok
  def dispatch_async(command) do
    GenServer.cast(__MODULE__, {:dispatch_async, command})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:dispatch, command}, _from, state) do
    result = Span.with_span "command_bus.dispatch", %{command_type: command.__struct__} do
      route_command(command)
    end
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:dispatch_async, command}, state) do
    Task.start(fn ->
      Span.with_span "command_bus.dispatch_async", %{command_type: command.__struct__} do
        case route_command(command) do
          {:ok, _} ->
            Logger.info("Command executed successfully: #{inspect(command.__struct__)}")
          {:error, reason} ->
            Logger.error("Command failed: #{inspect(command.__struct__)}, reason: #{reason}")
        end
      end
    end)
    
    {:noreply, state}
  end

  # Private functions

  defp route_command(%CommandService.Application.Commands.CategoryCommands.CreateCategory{} = cmd) do
    CategoryCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.CategoryCommands.UpdateCategory{} = cmd) do
    CategoryCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.CategoryCommands.DeleteCategory{} = cmd) do
    CategoryCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.CreateProduct{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.UpdateProduct{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.ChangeProductPrice{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.DeleteProduct{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.OrderCommands.CreateOrder{} = cmd) do
    OrderCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.OrderCommands.ConfirmOrder{} = cmd) do
    OrderCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.OrderCommands.CancelOrder{} = cmd) do
    OrderCommandHandler.handle(cmd)
  end

  # サガコマンドのルーティング
  defp route_command(%{command_type: "reserve_inventory"} = cmd) do
    SagaCommandHandler.handle_reserve_inventory(cmd)
  end

  defp route_command(%{command_type: "process_payment"} = cmd) do
    SagaCommandHandler.handle_process_payment(cmd)
  end

  defp route_command(%{command_type: "arrange_shipping"} = cmd) do
    SagaCommandHandler.handle_arrange_shipping(cmd)
  end

  defp route_command(%{command_type: "confirm_order"} = cmd) do
    SagaCommandHandler.handle_confirm_order(cmd)
  end

  defp route_command(%{command_type: "release_inventory"} = cmd) do
    SagaCommandHandler.handle_release_inventory(cmd)
  end

  defp route_command(%{command_type: "refund_payment"} = cmd) do
    SagaCommandHandler.handle_refund_payment(cmd)
  end

  defp route_command(%{command_type: "cancel_shipping"} = cmd) do
    SagaCommandHandler.handle_cancel_shipping(cmd)
  end

  defp route_command(%{command_type: "cancel_order"} = cmd) do
    SagaCommandHandler.handle_cancel_order(cmd)
  end

  defp route_command(command) do
    {:error, "Unknown command: #{inspect(command)}"}
  end
end