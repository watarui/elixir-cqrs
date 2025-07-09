defmodule CommandService.Application do
  @moduledoc """
  Command Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Ecto リポジトリ
      CommandService.Repo,
      # コマンドバス
      CommandService.Infrastructure.CommandBus,
      # コマンドリスナー（PubSub経由でコマンドを受信）
      CommandService.Infrastructure.CommandListener
    ]

    opts = [strategy: :one_for_one, name: CommandService.Supervisor]

    require Logger
    Logger.info("Starting Command Service with PubSub listener")

    Supervisor.start_link(children, opts)
  end
end
