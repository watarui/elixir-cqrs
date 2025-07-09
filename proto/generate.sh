#!/bin/bash

# Proto ファイルから Elixir コードを生成するスクリプト

set -e

PROTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$PROTO_DIR")"
SHARED_LIB_DIR="$PROJECT_ROOT/apps/shared/lib/proto"

echo "=== Protocol Buffers 生成スクリプト ==="
echo "プロジェクト root: $PROJECT_ROOT"
echo "出力ディレクトリ: $SHARED_LIB_DIR"
echo ""

# 必要なツールの確認
if ! command -v protoc >/dev/null 2>&1; then
    echo "エラー: protoc がインストールされていません"
    echo "インストール方法: brew install protobuf"
    exit 1
fi

if ! command -v protoc-gen-elixir >/dev/null 2>&1; then
    echo "エラー: protoc-gen-elixir がインストールされていません"
    echo "インストール方法: mix escript.install hex protobuf"
    exit 1
fi

echo "protoc バージョン: $(protoc --version)"
echo "protoc-gen-elixir バージョン: $(protoc-gen-elixir --version)"
echo ""

# 出力ディレクトリを作成
mkdir -p "$SHARED_LIB_DIR"

# protoc コマンドでコード生成
cd "$PROTO_DIR"

# 各 proto ファイルに対して生成
for proto_file in *.proto; do
    if [ -f "$proto_file" ]; then
        echo "Processing $proto_file..."
        
        # gRPC サービスが定義されているかチェック
        if grep -q "^service " "$proto_file"; then
            echo "  gRPC service found, generating with gRPC support"
            protoc \
                --elixir_out="plugins=grpc:$SHARED_LIB_DIR" \
                "$proto_file"
        else
            echo "  No gRPC service found, generating protobuf only"
            protoc \
                --elixir_out="$SHARED_LIB_DIR" \
                "$proto_file"
        fi
        
        if [ $? -eq 0 ]; then
            echo "  ✓ Successfully generated from $proto_file"
        else
            echo "  ✗ Failed to generate from $proto_file"
            exit 1
        fi
    fi
done

echo ""
echo "=== 生成完了 ==="
echo "Generated files are in: $SHARED_LIB_DIR"
echo ""
echo "Generated files:"
ls -la "$SHARED_LIB_DIR"/*.pb.ex 2>/dev/null || echo "  No .pb.ex files found"
echo ""
echo "Proto generation completed successfully!"