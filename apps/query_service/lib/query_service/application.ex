defmodule QueryService.Application do
  @moduledoc """
  Query Service アプリケーションのスーパーバイザー
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Ecto リポジトリ
      QueryService.Repo,
      # クエリバス
      QueryService.Infrastructure.QueryBus,
      # プロジェクションマネージャー
      QueryService.Infrastructure.ProjectionManager,
      # クエリリスナー（PubSub経由でクエリを受信）
      QueryService.Infrastructure.QueryListener
      # TODO: キャッシュ (ETS)
    ]

    opts = [strategy: :one_for_one, name: QueryService.Supervisor]

    require Logger
    Logger.info("Starting Query Service with PubSub listener")

    Supervisor.start_link(children, opts)
  end
end
