#!/bin/bash

# Script to generate Elixir code from protobuf files

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Generating Elixir code from protobuf files..."

# Create output directories
mkdir -p "$PROJECT_ROOT/apps/shared/lib/proto"

# Generate proto files
cd "$PROJECT_ROOT"

# Common proto files
protoc \
  --proto_path=priv/protos \
  --elixir_out=plugins=grpc:apps/shared/lib/proto \
  priv/protos/common.proto

# Command service proto files
protoc \
  --proto_path=priv/protos \
  --elixir_out=plugins=grpc:apps/shared/lib/proto \
  priv/protos/command_service.proto

# Query service proto files
protoc \
  --proto_path=priv/protos \
  --elixir_out=plugins=grpc:apps/shared/lib/proto \
  priv/protos/query_service.proto

echo "Proto generation completed!"