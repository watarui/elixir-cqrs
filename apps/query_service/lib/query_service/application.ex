defmodule QueryService.Application do
  @moduledoc """
  Query Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # TODO: データベース接続
      # TODO: キャッシュ (ETS)
      # TODO: プロジェクションマネージャー
      # TODO: gRPC エンドポイント
    ]

    opts = [strategy: :one_for_one, name: QueryService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end