defmodule QueryService.Infrastructure.Database.Repo do
  @moduledoc """
  Query Service用のデータベース接続

  Ectoを使用したPostgreSQL接続を提供します（読み取り専用）
  """

  use Ecto.Repo,
    otp_app: :query_service,
    adapter: Ecto.Adapters.Postgres
end
