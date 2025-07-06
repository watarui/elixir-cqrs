#!/usr/bin/env elixir

# Query Service 用のProtobuf生成スクリプト
Mix.install([
  {:protobuf_generate, "~> 0.1.1"}
])

defmodule ProtoGenerator do
  def generate_query_proto do
    # 入力ファイル
    proto_file = "proto/query.proto"

    # 出力ディレクトリ
    output_dir = "query-service/lib/proto"

    # ディレクトリが存在しない場合は作成
    File.mkdir_p!(output_dir)

    # Protobuf ファイルの生成
    case ProtobufGenerate.generate_files([proto_file], output_dir: output_dir) do
      :ok ->
        IO.puts("✅ Query Service Protobuf files generated successfully!")
        IO.puts("📁 Generated files in: #{output_dir}")

      {:error, reason} ->
        IO.puts("❌ Failed to generate Protobuf files: #{reason}")
        System.halt(1)
    end
  end
end

# 生成実行
ProtoGenerator.generate_query_proto()
