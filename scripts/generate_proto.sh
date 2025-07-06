#!/bin/bash

# Umbrella Project用Protocol Buffers生成スクリプト
#
# 使用方法: ./scripts/generate_proto.sh

set -e

echo "🔧 Generating Protocol Buffers for Umbrella Project..."

# 共有ライブラリディレクトリに移動
cd apps/shared

echo "📁 Working directory: $(pwd)"

# protoディレクトリの確認
if [ ! -d "proto" ]; then
  echo "❌ proto directory not found in apps/shared"
  exit 1
fi

# Protocol Buffersの生成
echo "🚀 Generating Protocol Buffers..."
mix protobuf.generate

echo "✅ Protocol Buffers generation completed successfully!"

# 生成されたファイルの確認
echo "📋 Generated files:"
find lib/proto -name "*.pb.ex" 2>/dev/null || echo "⚠️  No .pb.ex files found"

# ルートディレクトリに戻る
cd ../..

echo "🎉 All done! Protocol Buffers are ready for use in the Umbrella Project."
