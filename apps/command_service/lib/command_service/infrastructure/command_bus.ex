defmodule CommandService.Infrastructure.CommandBus do
  @moduledoc """
  コマンドバスの実装

  コマンドを適切なハンドラーにルーティングして実行します
  """

  use GenServer

  alias CommandService.Application.Handlers.{
    CategoryCommandHandler,
    OrderCommandHandler,
    ProductCommandHandler,
    SagaCommandHandler
  }

  alias Shared.Telemetry.Span
  alias Shared.Infrastructure.Retry.{RetryStrategy, RetryPolicy}

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
    result =
      Span.with_span "command_bus.dispatch", %{command_type: command.__struct__} do
        execute_command_with_retry(command)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:dispatch_async, command}, state) do
    Task.start(fn ->
      Span.with_span "command_bus.dispatch_async", %{command_type: command.__struct__} do
        case execute_command_with_retry(command) do
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

  defp route_command(
         %CommandService.Application.Commands.ProductCommands.ChangeProductPrice{} = cmd
       ) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.DeleteProduct{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.UpdateStock{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.ReserveStock{} = cmd) do
    ProductCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.ProductCommands.ReleaseStock{} = cmd) do
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
  defp route_command(%CommandService.Application.Commands.SagaCommands.ReserveInventory{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.ProcessPayment{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.ArrangeShipping{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.ConfirmOrder{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.ReleaseInventory{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.RefundPayment{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.CancelShipping{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(%CommandService.Application.Commands.SagaCommands.CancelOrder{} = cmd) do
    SagaCommandHandler.handle(cmd)
  end

  defp route_command(command) do
    {:error, "Unknown command: #{inspect(command)}"}
  end

  # リトライ機能を持つコマンド実行
  defp execute_command_with_retry(command) do
    RetryStrategy.execute_with_condition(
      fn ->
        try do
          route_command(command)
        rescue
          # データベース関連のエラー
          _e in [DBConnection.ConnectionError, Postgrex.Error] ->
            {:error, :database_timeout}

          # 楽観的ロック競合
          _e in [Ecto.StaleEntryError] ->
            {:error, :concurrent_modification}

          # イベントストアのバージョン競合
          _e in Shared.Infrastructure.EventStore.VersionConflictError ->
            {:error, :concurrent_modification}

          e ->
            # その他のエラーはリトライ不可能として扱う
            {:error, Exception.message(e)}
        end
      end,
      fn error ->
        RetryPolicy.retryable?(error)
      end,
      %{
        max_attempts: 3,
        base_delay: 50,
        max_delay: 1_000,
        backoff_type: :exponential,
        jitter: true
      }
    )
    |> case do
      {:ok, result} ->
        result

      {:error, :max_attempts_exceeded, errors} ->
        last_error = errors |> List.last() |> elem(1)
        {:error, last_error}

      {:error, error} ->
        {:error, error}
    end
  end
end
