defmodule ClientService.Infrastructure.RemoteCommandBus do
  @moduledoc """
  リモートコマンドバス

  PubSub を使用して Command Service にコマンドを送信し、
  レスポンスを非同期で受信します。
  """

  use GenServer

  alias Shared.Infrastructure.EventBus

  require Logger

  @command_topic :commands
  @response_timeout 5_000

  # クライアント API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  コマンドを送信してレスポンスを待つ
  """
  def send_command(command) do
    GenServer.call(__MODULE__, {:send_command, command}, @response_timeout + 1_000)
  end

  # サーバーコールバック

  @impl true
  def init(_opts) do
    # レスポンス用のトピックを購読
    node_name = node() |> to_string() |> String.replace("@", "_at_") |> String.replace(".", "_")
    response_topic = String.to_atom("command_responses_#{node_name}")
    EventBus.subscribe(response_topic)

    state = %{
      pending_requests: %{},
      response_topic: response_topic
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send_command, command}, from, state) do
    # リクエスト ID を生成
    request_id = UUID.uuid4()

    Logger.info(
      "RemoteCommandBus sending command: type=#{inspect(command[:command_type])}, request_id=#{request_id}"
    )

    # コマンドメッセージを作成
    message = %{
      request_id: request_id,
      command: command,
      reply_to: state.response_topic,
      timestamp: DateTime.utc_now()
    }

    Logger.debug("Publishing to topic #{@command_topic}, reply_to: #{state.response_topic}")

    # コマンドを発行
    EventBus.publish(@command_topic, message)

    # ペンディングリクエストに追加
    pending_requests = Map.put(state.pending_requests, request_id, from)

    # タイムアウトタイマーを設定
    Process.send_after(self(), {:timeout, request_id}, @response_timeout)

    {:noreply, %{state | pending_requests: pending_requests}}
  end

  @impl true
  def handle_info({:event, response}, state) when is_map(response) do
    Logger.info(
      "RemoteCommandBus received response: request_id=#{inspect(Map.get(response, :request_id))}"
    )

    case Map.get(state.pending_requests, response.request_id) do
      nil ->
        # 未知のレスポンス（すでにタイムアウトしたか、別のノードへのレスポンス）
        Logger.warning("Received response for unknown request_id: #{response.request_id}")
        {:noreply, state}

      from ->
        # クライアントにレスポンスを返す
        Logger.info("Returning response to client: #{inspect(response.result)}")
        GenServer.reply(from, response.result)

        # ペンディングリクエストから削除
        pending_requests = Map.delete(state.pending_requests, response.request_id)
        {:noreply, %{state | pending_requests: pending_requests}}
    end
  end

  @impl true
  def handle_info({:timeout, request_id}, state) do
    case Map.get(state.pending_requests, request_id) do
      nil ->
        # すでに処理済み
        {:noreply, state}

      from ->
        # タイムアウトエラーを返す
        GenServer.reply(from, {:error, :timeout})

        # ペンディングリクエストから削除
        pending_requests = Map.delete(state.pending_requests, request_id)
        {:noreply, %{state | pending_requests: pending_requests}}
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
