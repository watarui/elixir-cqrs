defmodule CommandService.Infrastructure.CommandListener do
  @moduledoc """
  コマンドリスナー

  PubSub からコマンドを受信し、CommandBus で処理してレスポンスを返します。
  """

  use GenServer

  alias Shared.Infrastructure.EventBus
  alias CommandService.Infrastructure.CommandBus

  require Logger

  @command_topic :commands

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # コマンドトピックを購読
    EventBus.subscribe(@command_topic)
    Logger.info("CommandListener started and subscribed to commands")

    {:ok, %{}}
  end

  @impl true
  def handle_info({:event, message}, state) when is_map(message) do
    Logger.info("CommandListener received command: #{inspect(message)}")

    # 非同期でコマンドを処理
    Task.start(fn ->
      process_command(message)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp process_command(%{request_id: request_id, command: command, reply_to: reply_to}) do
    Logger.info(
      "Processing command: request_id=#{request_id}, type=#{inspect(command[:command_type])}, reply_to=#{reply_to}"
    )

    Logger.debug("Full command data: #{inspect(command)}")

    # コマンドバリデーションと変換
    validated_command = validate_and_convert_command(command)

    # コマンドを実行
    result =
      case validated_command do
        {:ok, cmd} -> CommandBus.dispatch(cmd)
        error -> error
      end

    # レスポンスを作成
    response = %{
      request_id: request_id,
      result: result,
      timestamp: DateTime.utc_now()
    }

    # レスポンスを返信
    EventBus.publish(reply_to, response)
  rescue
    error ->
      Logger.error("Error processing command: #{inspect(error)}")

      # エラーレスポンスを返信
      response = %{
        request_id: request_id,
        result: {:error, "Command processing failed: #{inspect(error)}"},
        timestamp: DateTime.utc_now()
      }

      EventBus.publish(reply_to, response)
  end

  defp validate_and_convert_command(command_map) do
    case command_map[:command_type] do
      "category.create" ->
        CommandService.Application.Commands.CategoryCommands.CreateCategory.validate(%{
          name: command_map[:name],
          description: command_map[:description],
          metadata: command_map[:metadata] || %{}
        })

      "category.update" ->
        CommandService.Application.Commands.CategoryCommands.UpdateCategory.validate(%{
          id: command_map[:id],
          name: command_map[:name],
          description: command_map[:description],
          metadata: command_map[:metadata] || %{}
        })

      "category.delete" ->
        CommandService.Application.Commands.CategoryCommands.DeleteCategory.validate(%{
          id: command_map[:id],
          metadata: command_map[:metadata] || %{}
        })

      "product.create" ->
        CommandService.Application.Commands.ProductCommands.CreateProduct.validate(%{
          name: command_map[:name],
          price: command_map[:price],
          category_id: command_map[:category_id],
          metadata: command_map[:metadata] || %{}
        })

      "product.update" ->
        CommandService.Application.Commands.ProductCommands.UpdateProduct.validate(%{
          id: command_map[:id],
          name: command_map[:name],
          price: command_map[:price],
          category_id: command_map[:category_id],
          metadata: command_map[:metadata] || %{}
        })

      "product.delete" ->
        CommandService.Application.Commands.ProductCommands.DeleteProduct.validate(%{
          id: command_map[:id],
          metadata: command_map[:metadata] || %{}
        })

      "product.change_price" ->
        CommandService.Application.Commands.ProductCommands.ChangeProductPrice.validate(%{
          id: command_map[:id],
          new_price: command_map[:new_price],
          metadata: command_map[:metadata] || %{}
        })

      "product.update_stock" ->
        CommandService.Application.Commands.ProductCommands.UpdateStock.validate(%{
          product_id: command_map[:product_id],
          quantity: command_map[:quantity],
          metadata: command_map[:metadata] || %{}
        })

      type ->
        {:error, "Unknown command type: #{type}"}
    end
  end
end
