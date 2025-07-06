#!/bin/bash

# Client Service 用の Protocol Buffers コード生成スクリプト

echo "Generating Protocol Buffers code for Client Service..."

# 基本的なproto ファイルを生成
mix protobuf.generate \
  --output-path=./lib \
  --include-path=proto \
  proto/models.proto

# gRPC 対応のproto ファイルを生成（エラー、コマンド、クエリ用）
mix protobuf.generate \
  --output-path=./lib \
  --include-path=proto \
  --plugin=ProtobufGenerate.Plugins.GRPC \
  proto/error.proto \
  proto/command.proto \
  proto/query.proto

echo "Protocol Buffers code generation completed for Client Service!"
