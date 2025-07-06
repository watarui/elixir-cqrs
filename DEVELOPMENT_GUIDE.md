# 開発ガイドライン

## Git 管理戦略

### リポジトリ構成

- **戦略**: Monorepo（単一リポジトリ）
- **場所**: ルートディレクトリ（elixir-cqrs/）
- **理由**: Umbrella Project との統合性、依存関係管理の简便性

### ブランチ戦略

```
main                # 本番用（安定版）
├── develop         # 開発統合
├── feature/*       # 機能開発
├── hotfix/*        # 緊急修正
└── release/*       # リリース準備
```

### コミット規約

```
type: subject

feat: 新機能
fix: バグ修正
docs: ドキュメント
style: コードスタイル
refactor: リファクタリング
test: テスト追加
chore: ビルド・設定
```

## マイクロサービス開発

### サービス別開発

```bash
# Command Service開発
cd apps/command_service
mix test
mix compile

# Query Service開発
cd apps/query_service
mix test
mix compile

# Client Service開発
cd apps/client_service
mix phx.server
```

### 統合開発

```bash
# 全サービス依存関係
mix deps.get

# 全サービステスト
mix test

# 全サービス起動
mix start.all
```

### API 開発ワークフロー

1. **Protocol Buffers 更新**

   ```bash
   # proto定義修正
   vim proto/models.proto

   # 生成
   ./scripts/generate_proto.sh
   ```

2. **Command Service 開発**

   ```bash
   cd apps/command_service
   # ドメインモデル → アプリケーションサービス → インフラ
   ```

3. **Query Service 開発**

   ```bash
   cd apps/query_service
   # リポジトリ → サービス → gRPCサーバー
   ```

4. **Client Service 統合**
   ```bash
   cd apps/client_service
   # GraphQLリゾルバー → テスト
   ```

## デプロイ戦略

### 現在（一括デプロイ）

```bash
mix release --env=prod
```

### 将来（個別デプロイ）

```bash
# Dockerコンテナ化
docker build -t command-service ./apps/command_service
docker build -t query-service ./apps/query_service
docker build -t client-service ./apps/client_service

# Kubernetes デプロイ
kubectl apply -f k8s/
```

## 品質管理

### コードレビュー

- Pull Request 必須
- 全サービスのテスト通過
- Credo 静的解析クリア

### 継続的インテグレーション

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Elixir
        run: mix deps.get
      - name: Run tests
        run: mix test
      - name: Code quality
        run: mix quality
```
