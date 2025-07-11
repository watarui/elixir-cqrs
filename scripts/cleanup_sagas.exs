#!/usr/bin/env elixir

# 古い SAGA をクリーンアップするスクリプト

# プロジェクトディレクトリに移動
File.cd!("apps/shared")

# Mix を起動
Code.require_file("../../mix.exs")
Mix.start()
Mix.env(:dev)

# 依存関係を読み込み
Mix.Task.run("loadpaths")

# アプリケーションの起動
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
Application.load(:shared)

# Repoを手動で起動
repo_config = [
  database: "cqrs_command",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10
]

{:ok, _} = Ecto.Adapters.Postgres.ensure_all_started(Shared.Infrastructure.Persistence.CommandRepo, :temporary)
{:ok, _} = Shared.Infrastructure.Persistence.CommandRepo.start_link(repo_config)

# Repo のエイリアス
alias Shared.Infrastructure.Persistence.CommandRepo
alias Shared.Infrastructure.Saga.SagaRepository

IO.puts("古い SAGA のクリーンアップを開始します...")

# アクティブな SAGA を取得
case SagaRepository.get_active_sagas() do
  {:ok, sagas} ->
    IO.puts("アクティブな SAGA の数: #{length(sagas)}")
    
    # 各 SAGA の状態を確認
    Enum.each(sagas, fn saga ->
      IO.puts("SAGA ID: #{saga.saga_id}, Type: #{saga.saga_type}, Status: #{saga.status}")
    end)
    
    # 古い SAGA を削除するかユーザーに確認
    if length(sagas) > 0 do
      IO.puts("\nこれらの SAGA を削除しますか？ (y/n)")
      answer = IO.gets("") |> String.trim()
      
      if answer == "y" do
        # SQL で直接削除
        sql = "DELETE FROM sagas WHERE status IN ('started', 'processing')"
        
        case CommandRepo.query(sql, []) do
          {:ok, %{num_rows: num_rows}} ->
            IO.puts("#{num_rows} 件の SAGA を削除しました")
          {:error, error} ->
            IO.puts("エラーが発生しました: #{inspect(error)}")
        end
      else
        IO.puts("キャンセルしました")
      end
    else
      IO.puts("削除する SAGA はありません")
    end
    
  {:error, error} ->
    IO.puts("SAGA の取得中にエラーが発生しました: #{inspect(error)}")
end

IO.puts("\n完了しました")