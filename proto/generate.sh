#!/bin/bash

# Proto ファイルから Elixir コードを生成するスクリプト

set -e

PROTO_DIR=$(dirname "$0")
PROJECT_ROOT=$(dirname "$PROTO_DIR")
SHARED_LIB_DIR="$PROJECT_ROOT/apps/shared/lib/shared/proto"

echo "Generating Elixir code from proto files..."

# 出力ディレクトリを作成
mkdir -p "$SHARED_LIB_DIR"

# protoc コマンドでコード生成
cd "$PROTO_DIR"

# 各 proto ファイルに対して生成
for proto_file in *.proto; do
    if [ -f "$proto_file" ]; then
        echo "Processing $proto_file..."
        protoc \
            --elixir_out="$SHARED_LIB_DIR" \
            --grpc_elixir_out="$SHARED_LIB_DIR" \
            "$proto_file"
    fi
done

echo "Proto generation completed!"
echo "Generated files are in: $SHARED_LIB_DIR"