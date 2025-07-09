defmodule QueryService.Infrastructure.QueryListener do
  @moduledoc """
  クエリリスナー

  PubSub からクエリを受信し、QueryBus で処理してレスポンスを返します。
  """

  use GenServer

  alias Shared.Infrastructure.EventBus
  alias QueryService.Infrastructure.QueryBus

  require Logger

  @query_topic :queries

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # クエリトピックを購読
    EventBus.subscribe(@query_topic)
    Logger.info("QueryListener started and subscribed to queries")

    {:ok, %{}}
  end

  @impl true
  def handle_info({:event, message}, state) when is_map(message) do
    # 非同期でクエリを処理
    Task.start(fn ->
      process_query(message)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp process_query(%{request_id: request_id, query: query, reply_to: reply_to}) do
    Logger.debug("Processing query: #{inspect(query.__struct__)}")

    # クエリを実行
    result = QueryBus.dispatch(query)

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
      Logger.error("Error processing query: #{inspect(error)}")

      # エラーレスポンスを返信
      response = %{
        request_id: request_id,
        result: {:error, "Query processing failed: #{inspect(error)}"},
        timestamp: DateTime.utc_now()
      }

      EventBus.publish(reply_to, response)
  end
end
