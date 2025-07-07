# Docker 化ガイド

このディレクトリには、Elixir CQRS マイクロサービスの Docker 化に必要なファイルが含まれています。

## ファイル構成

```
docker/
├── README.md                    # このファイル
├── command_service_start.sh     # Command Service 起動スクリプト
├── query_service_start.sh       # Query Service 起動スクリプト
└── nginx.conf                   # Nginx 設定ファイル
```

## 使用方法

### 1. 全サービスを起動

```bash
# 全サービスをビルドして起動
docker-compose up --build

# バックグラウンドで起動
docker-compose up -d --build
```

### 2. 個別サービスを起動

```bash
# データベースのみ起動
docker-compose up postgres-command postgres-query

# Command Service のみ起動
docker-compose up command-service

# Query Service のみ起動
docker-compose up query-service

# Client Service のみ起動
docker-compose up client-service
```

### 3. サービスの停止

```bash
# 全サービスを停止
docker-compose down

# ボリュームも削除
docker-compose down -v
```

### 4. ログの確認

```bash
# 全サービスのログ
docker-compose logs

# 特定サービスのログ
docker-compose logs client-service
docker-compose logs command-service
docker-compose logs query-service

# リアルタイムログ
docker-compose logs -f client-service
```

## アクセス方法

### 開発環境

- **Client Service (GraphQL API)**: http://localhost:4000
- **Command Service (gRPC)**: localhost:50051
- **Query Service (gRPC)**: localhost:50052
- **Nginx Load Balancer**: http://localhost:80

### コンテナ内

- **Client Service**: http://client-service:4000
- **Command Service**: command-service:50051
- **Query Service**: query-service:50052

## データベース

### 接続情報

**Command Service 用データベース:**

- Host: localhost (開発環境) / postgres-command (コンテナ内)
- Port: 5432
- Database: command_service_dev
- Username: postgres
- Password: postgres

**Query Service 用データベース:**

- Host: localhost (開発環境) / postgres-query (コンテナ内)
- Port: 5433 (開発環境) / 5432 (コンテナ内)
- Database: query_service_dev
- Username: postgres
- Password: postgres

### データベース操作

```bash
# Command Service データベースに接続
docker exec -it elixir-cqrs-postgres-command psql -U postgres -d command_service_dev

# Query Service データベースに接続
docker exec -it elixir-cqrs-postgres-query psql -U postgres -d query_service_dev
```

## トラブルシューティング

### よくある問題

1. **ポートが既に使用されている**

   ```bash
   # 使用中のポートを確認
   lsof -i :4000 -i :50051 -i :50052 -i :5432 -i :5433

   # 既存のコンテナを停止
   docker-compose down
   ```

2. **データベース接続エラー**

   ```bash
   # データベースの状態を確認
   docker-compose ps

   # データベースログを確認
   docker-compose logs postgres-command
   docker-compose logs postgres-query
   ```

3. **ビルドエラー**
   ```bash
   # キャッシュをクリアして再ビルド
   docker-compose build --no-cache
   ```

### 開発時のヒント

1. **ホットリロード**

   - ソースコードを変更した場合、コンテナを再起動する必要があります
   - 開発時は `docker-compose up --build` を使用してください

2. **デバッグ**

   ```bash
   # コンテナ内でシェルを起動
   docker exec -it elixir-cqrs-client-service sh
   docker exec -it elixir-cqrs-command-service sh
   docker exec -it elixir-cqrs-query-service sh
   ```

3. **環境変数の変更**
   - `docker-compose.yml` の `environment` セクションを編集
   - 変更後は `docker-compose up --build` で再起動

## 本番環境での使用

本番環境では以下の点を考慮してください：

1. **セキュリティ**

   - デフォルトのパスワードを変更
   - 環境変数で機密情報を管理
   - ネットワークセキュリティの設定

2. **パフォーマンス**

   - リソース制限の設定
   - ログローテーションの設定
   - バックアップ戦略の実装

3. **監視**
   - ヘルスチェックの設定
   - メトリクス収集の実装
   - アラート設定

## 次のステップ

1. **CI/CD パイプラインの構築**
2. **監視・ログ収集の実装**
3. **負荷テストの実施**
4. **Kubernetes 対応**
