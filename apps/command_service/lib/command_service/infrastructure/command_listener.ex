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
    Logger.debug("Processing command: #{inspect(command.__struct__)}")

    # コマンドを実行
    result = CommandBus.dispatch(command)

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
end
