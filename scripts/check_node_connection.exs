#!/usr/bin/env elixir

# ノード間の接続状態を確認するスクリプト

defmodule NodeConnectionChecker do
  @moduledoc """
  Elixir ノード間の接続状態を確認するためのユーティリティ
  """

  @node_configs [
    {:command_service, :"command@127.0.0.1"},
    {:query_service, :"query@127.0.0.1"},
    {:client_service, :"client@127.0.0.1"}
  ]

  def run do
    IO.puts("🔍 ノード接続状態の確認を開始します")
    IO.puts("========================================")
    IO.puts("")

    # 現在のノード情報
    current_node = Node.self()
    cookie = Node.get_cookie()
    
    IO.puts("📍 現在のノード情報:")
    IO.puts("  - ノード名: #{current_node}")
    IO.puts("  - Cookie: #{cookie}")
    IO.puts("")

    # 各ノードへの接続テスト
    IO.puts("🔗 ノード接続テスト:")
    
    results = Enum.map(@node_configs, fn {service, node} ->
      IO.write("  - #{service} (#{node}): ")
      
      case test_connection(node) do
        :connected ->
          IO.puts("✅ 接続成功")
          {:ok, service}
        :already_connected ->
          IO.puts("✅ 既に接続済み")
          {:ok, service}
        {:error, reason} ->
          IO.puts("❌ 接続失敗: #{reason}")
          {:error, service, reason}
      end
    end)

    # 接続されているノードの一覧
    IO.puts("")
    IO.puts("📋 接続済みノード一覧:")
    connected_nodes = Node.list()
    
    if connected_nodes == [] do
      IO.puts("  なし")
    else
      Enum.each(connected_nodes, fn node ->
        IO.puts("  - #{node}")
      end)
    end

    # Phoenix.PubSub の確認
    IO.puts("")
    IO.puts("📡 Phoenix.PubSub の状態:")
    check_pubsub()

    # サマリー
    IO.puts("")
    IO.puts("========================================")
    
    success_count = Enum.count(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    if success_count == length(@node_configs) do
      IO.puts("✅ すべてのノードに正常に接続できました")
    else
      IO.puts("⚠️  一部のノードへの接続に問題があります")
      IO.puts("")
      IO.puts("トラブルシューティング:")
      IO.puts("1. すべてのサービスが起動していることを確認してください")
      IO.puts("2. ノード名と Cookie が正しく設定されているか確認してください")
      IO.puts("3. ファイアウォールやネットワーク設定を確認してください")
    end
  end

  defp test_connection(node) do
    case Node.ping(node) do
      :pong ->
        if node in Node.list() do
          :already_connected
        else
          case Node.connect(node) do
            true -> :connected
            false -> {:error, "接続を確立できませんでした"}
          end
        end
      :pang ->
        {:error, "ノードが応答しません"}
    end
  end

  defp check_pubsub do
    # Phoenix.PubSub のプロセスを確認
    pubsub_name = ElixirCqrs.PubSub
    
    case Process.whereis(pubsub_name) do
      nil ->
        IO.puts("  ❌ PubSub プロセスが見つかりません")
      pid ->
        IO.puts("  ✅ PubSub プロセスが実行中です (PID: #{inspect(pid)})")
        
        # PubSub のノード情報を取得
        try do
          # PubSub.node_name/1 を使用してノード情報を取得
          nodes = Phoenix.PubSub.node_name(pubsub_name)
          IO.puts("  - 現在のノード: #{nodes}")
        rescue
          _ ->
            IO.puts("  - ノード情報の取得に失敗しました")
        end
    end
  end
end

# メイン実行
NodeConnectionChecker.run()