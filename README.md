# Elixir CQRS Study Project

Elixir/Phoenix を使用した CQRS + イベントソーシング + サガパターンの学習用実装です。

## プロジェクト概要

個人的なアーキテクチャ勉強のために、マイクロサービスパターンを実装したサンプルプロジェクトです。

## アーキテクチャ概要

- Client Service (GraphQL) - ポート 4000
- Command Service (gRPC) - ポート 50051
- Query Service (gRPC) - ポート 50052
- PostgreSQL - ポート 5432-5434

詳細な設計については [アーキテクチャ設計書](docs/architecture.md) を参照してください。

## Quick Start

### Docker Compose による起動（推奨）

```bash
# 開発環境の起動（データベース作成・マイグレーション自動実行）
docker compose up -d

# 監視スタックも含めて起動
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d

# ログの確認
docker compose logs -f
```

## API アクセス

GraphQL Playground: http://localhost:4000/graphiql

使用例や API 仕様については [API 仕様書](docs/api-specification.md) を参照してください。

## 実装内容

- CQRS パターン
- イベントソーシング
- サガパターン
- gRPC/GraphQL 通信
- 監視・可観測性

詳細については以下のドキュメントを参照：

- [イベントソーシングガイド](docs/event-sourcing.md)
- [サガパターン実装ガイド](docs/saga-pattern.md)

## プロジェクト構造

```
elixir-cqrs/
├── apps/
│   ├── client_service/         # GraphQL API Gateway
│   │   ├── graphql/           # GraphQLスキーマ・リゾルバー
│   │   ├── application/       # CQRSファサード
│   │   └── infrastructure/    # gRPC接続管理
│   │
│   ├── command_service/        # 書き込み専用サービス
│   │   ├── domain/            # ドメイン層
│   │   │   ├── aggregates/    # イベントソーシングアグリゲート
│   │   │   ├── commands/      # コマンド定義
│   │   │   └── events/        # ドメインイベント
│   │   ├── application/       # アプリケーション層
│   │   │   ├── handlers/      # コマンドハンドラー
│   │   │   └── command_bus.ex # コマンドバス
│   │   └── infrastructure/    # インフラ層
│   │
│   ├── query_service/          # 読み取り専用サービス
│   │   ├── domain/            # 読み取りモデル
│   │   ├── application/       # クエリハンドラー
│   │   └── infrastructure/    # キャッシュ・リポジトリ
│   │
│   └── shared/                 # 共有ライブラリ
│       ├── domain/            # 共通ドメイン定義
│       ├── infrastructure/    # 共通インフラ
│       │   ├── event_store/   # イベントストア
│       │   ├── saga/          # サガパターン実装
│       │   └── telemetry/     # 監視・メトリクス
│       └── proto/             # Protocol Buffers定義
│
├── docker/                     # Docker設定
├── k8s/                       # Kubernetes マニフェスト
└── docs/                      # ドキュメント
```

## 技術スタック

- Elixir 1.18 / Phoenix 1.7
- PostgreSQL 14
- Docker / Kubernetes
- Prometheus / Grafana / Jaeger

## 監視

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)
- Jaeger: http://localhost:16686

詳細は [運用マニュアル](docs/operations.md) を参照してください。

## テスト

```bash
# 全テストの実行
mix test

# カバレッジレポート付き
mix test --cover

# 特定のサービスのテスト
cd apps/command_service && mix test
```

## ドキュメント

- [アーキテクチャ設計書](docs/architecture.md)
- [API 仕様書](docs/api-specification.md)
- [サガパターン実装ガイド](docs/saga-pattern.md)
- [イベントソーシングガイド](docs/event-sourcing.md)
- [運用マニュアル](docs/operations.md)
