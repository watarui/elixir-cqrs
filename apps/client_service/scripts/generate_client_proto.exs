#!/usr/bin/env elixir

Mix.install([:protobuf_generate])

defmodule ClientProtoGenerator do
  @moduledoc """
  Client Service用のProtocol Buffers コード生成
  """

  def generate_all do
    IO.puts("🚀 Generating Protocol Buffers for Client Service...")

    # 出力ディレクトリの作成
    File.mkdir_p!("lib/proto")

    # 各protoファイルのコード生成
    generate_proto_files()

    IO.puts("✅ Protocol Buffers generation completed!")
  end

  defp generate_proto_files do
    proto_files = [
      "command.proto",
      "query.proto",
      "models.proto",
      "error.proto"
    ]

    Enum.each(proto_files, fn proto_file ->
      IO.puts("📦 Generating #{proto_file}...")

      case ProtobufGenerate.generate(
             Path.join(["proto", proto_file]),
             output_path: "lib/proto",
             include_path: "proto"
           ) do
        :ok ->
          IO.puts("✅ Successfully generated #{proto_file}")

        {:error, reason} ->
          IO.puts("❌ Failed to generate #{proto_file}: #{inspect(reason)}")
          System.halt(1)
      end
    end)
  end
end

# スクリプト実行
ClientProtoGenerator.generate_all()
