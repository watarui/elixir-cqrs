defmodule CommandService.Application do
  @moduledoc """
  Command Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # TODO: イベントストア
      # TODO: リポジトリ
      # TODO: コマンドバス
      # TODO: gRPC エンドポイント
    ]

    opts = [strategy: :one_for_one, name: CommandService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end