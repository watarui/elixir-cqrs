defmodule CommandService.Infrastructure.Database.Repo do
  @moduledoc """
  Command Service用のデータベース接続

  Ectoを使用したPostgreSQL接続を提供します
  """

  use Ecto.Repo,
    otp_app: :command_service,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config) do
    # 環境変数からDATABASE_URLを取得
    database_url = System.get_env("DATABASE_URL")

    if database_url do
      # DATABASE_URLが設定されている場合は、それを使用
      {:ok, Keyword.put(config, :url, database_url)}
    else
      # 設定されていない場合は、既存の設定を使用
      {:ok, config}
    end
  end
end
