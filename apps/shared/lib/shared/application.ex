defmodule Shared.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # イベントストアの起動
      {Shared.Infrastructure.EventStore.PostgresAdapter, event_store_config()}
    ]

    opts = [strategy: :one_for_one, name: Shared.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp event_store_config do
    # 環境変数またはアプリケーション設定から読み込み
    if Mix.env() == :test do
      [
        hostname: System.get_env("EVENT_STORE_HOST", "localhost"),
        database: System.get_env("EVENT_STORE_TEST_DB", "event_store_test"),
        username: System.get_env("EVENT_STORE_USER", "postgres"),
        password: System.get_env("EVENT_STORE_PASSWORD", "postgres"),
        port: System.get_env("EVENT_STORE_PORT", "5432") |> String.to_integer()
      ]
    else
      [
        hostname: System.get_env("EVENT_STORE_HOST", "postgres-event"),
        database: System.get_env("EVENT_STORE_DB", "event_store"),
        username: System.get_env("EVENT_STORE_USER", "postgres"),
        password: System.get_env("EVENT_STORE_PASSWORD", "postgres"),
        port: System.get_env("EVENT_STORE_PORT", "5432") |> String.to_integer()
      ]
    end
  end
end
