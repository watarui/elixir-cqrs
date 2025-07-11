#!/bin/bash

# サービスを停止するスクリプト

echo "Stopping services..."

# プロセスを停止
ps aux | grep -E "elixir.*@127.0.0.1" | grep -v grep | awk '{print $2}' | xargs -r kill -9

echo "Services stopped"