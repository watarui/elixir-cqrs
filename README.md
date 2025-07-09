# Elixir CQRS/ES/SAGA マイクロサービス

CQRS（Command Query Responsibility Segregation）、Event Sourcing、SAGA パターンを実装した学習用マイクロサービスアーキテクチャです。

## アーキテクチャ概要

```
┌─────────────────┐
│  Client Service │ GraphQL API (Port 4000)
└────────┬────────┘
         │ gRPC
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼────┐
│Command│ │ Query │
│Service│ │Service│
│ :50051│ │ :50052│
└───┬───┘ └──┬────┘
    │         │
┌───▼─────────▼───┐
│   Event Store   │
│  (PostgreSQL)   │
└─────────────────┘
```

## 技術スタック

- **言語**: Elixir 1.18 / Erlang OTP 27
- **フレームワーク**: Phoenix 1.7
- **データベース**: PostgreSQL 16
- **API**: GraphQL (Absinthe) / gRPC
- **監視**: Jaeger, Prometheus, Grafana

## セットアップ

### 前提条件

- Elixir 1.18 以上
- Docker & Docker Compose
- PostgreSQL クライアント（オプション）

### 初期セットアップ

```bash
# Docker コンテナの起動とセットアップ
make setup

# または個別に実行
make docker-up   # Docker コンテナ起動
make deps        # 依存関係インストール
make migrate     # データベースマイグレーション
```

## 開発

### サービスの起動

```bash
# すべてのサービスを起動
iex -S mix

# 個別に起動
cd apps/command_service && iex -S mix
cd apps/query_service && iex -S mix
cd apps/client_service && iex -S mix phx.server
```

### 便利なコマンド

```bash
make test        # テスト実行
make check       # コード品質チェック
make format      # コードフォーマット
make reset       # データベースリセット
make docker-logs # Docker ログ表示
```

## 監視ツール

- **Jaeger UI**: http://localhost:16686
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **GraphQL Playground**: http://localhost:4000/graphiql

## プロジェクト構造

```
apps/
├── shared/          # 共通モジュール（値オブジェクト、イベント定義）
├── command_service/ # コマンド処理（書き込み）
├── query_service/   # クエリ処理（読み取り）
└── client_service/  # GraphQL API ゲートウェイ
```

## 主な機能

- **カテゴリ管理**: 作成、更新、削除
- **商品管理**: 作成、更新、価格変更、削除
- **注文処理**: SAGA パターンによる分散トランザクション
- **イベントソーシング**: すべての状態変更をイベントとして記録
- **CQRS**: 読み取りと書き込みの完全分離

## ライセンス

このプロジェクトは学習目的で作成されています。