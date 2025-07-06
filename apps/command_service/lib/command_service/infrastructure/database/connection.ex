defmodule CommandService.Infrastructure.Database.Repo do
  @moduledoc """
  Command Service用のデータベース接続

  Ectoを使用したPostgreSQL接続を提供します
  """

  use Ecto.Repo,
    otp_app: :command_service,
    adapter: Ecto.Adapters.Postgres
end
