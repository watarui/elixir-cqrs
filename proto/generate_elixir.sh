#!/bin/bash

# ElixirのProtocol Buffersコードを生成するスクリプト

# 出力ディレクトリを作成
mkdir -p gen

# protoc-gen-elixirがインストールされているかチェック
if ! command -v protoc-gen-elixir &>/dev/null; then
  echo "protoc-gen-elixir is not installed. Please install it first:"
  echo "mix escript.install hex protobuf"
  exit 1
fi

# Elixirコードを生成
echo "Generating Elixir code from proto files..."

protoc \
  --elixir_out=gen \
  --proto_path=. \
  models.proto \
  error.proto \
  command.proto \
  query.proto

echo "Elixir code generation completed!"
echo "Generated files are in the gen/ directory"
