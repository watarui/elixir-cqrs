#!/bin/bash

# Query Service 用の Protocol Buffers コード生成スクリプト

echo "Generating Protocol Buffers code for Query Service..."

# 基本的なproto ファイルを生成
mix protobuf.generate \
  --output-path=./lib \
  --include-path=priv/proto \
  priv/proto/models.proto

# gRPC 対応のproto ファイルを生成（エラーとクエリ用）
mix protobuf.generate \
  --output-path=./lib \
  --include-path=priv/proto \
  --plugin=ProtobufGenerate.Plugins.GRPC \
  priv/proto/error.proto \
  priv/proto/query.proto

echo "Protocol Buffers code generation completed for Query Service!"
