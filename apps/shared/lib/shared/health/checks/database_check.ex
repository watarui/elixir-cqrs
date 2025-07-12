defmodule Shared.Health.Checks.DatabaseCheck do
  @moduledoc """
  データベース接続のヘルスチェック

  各データベース（コマンド、クエリ、イベントストア）の接続状態を確認します。
  """

  require Logger

  @timeout 5_000

  @doc """
  全データベースの接続状態を確認
  """
  def check do
    results = %{
      command_db: check_repo(CommandService.Repo, "command"),
      query_db: check_repo(QueryService.Repo, "query"),
      event_store_db: check_repo(Shared.Infrastructure.EventStore.Repo, "event_store")
    }

    failures =
      results
      |> Enum.filter(fn {_, result} -> result != :ok end)
      |> Enum.map(fn {db, _} -> db end)

    if Enum.empty?(failures) do
      {:ok, results}
    else
      {:error, "Database connections failed: #{inspect(failures)}", results}
    end
  end

  defp check_repo(repo, name) do
    try do
      # アプリケーションが起動していない場合はスキップ
      case Process.whereis(repo) do
        nil ->
          Logger.debug("Repository not started", repo: repo)
          :not_started

        _pid ->
          # 簡単なクエリを実行して接続を確認
          task =
            Task.async(fn ->
              repo.query!("SELECT 1", [])
            end)

          case Task.yield(task, @timeout) || Task.shutdown(task) do
            {:ok, _result} ->
              :ok

            nil ->
              Logger.error("Database query timeout", repo: name, timeout: @timeout)
              :timeout

            {:exit, reason} ->
              Logger.error("Database query failed", repo: name, reason: inspect(reason))
              :error
          end
      end
    rescue
      e ->
        Logger.error("Database check failed", repo: name, error: inspect(e))
        :error
    end
  end
end
