# トラブルシューティング

## よくある問題と解決方法

### 起動時の問題

#### gRPC サービスに接続できない

**症状**:
```
[error] Failed to connect to Command Service: :timeout
[error] Failed to connect to Query Service: :timeout
```

**原因と解決方法**:

1. **サービスが起動していない**
   - 3つのサービスを正しい順序で起動しているか確認
   - Command Service → Query Service → Client Service の順で起動

2. **ポートが使用中**
   ```bash
   # ポートの使用状況を確認
   lsof -i :50051
   lsof -i :50052
   lsof -i :4000
   ```

3. **Docker コンテナが起動していない**
   ```bash
   docker compose ps
   # 起動していない場合
   docker compose up -d
   ```

#### データベース接続エラー

**症状**:
```
** (DBConnection.ConnectionError) connection not available and request was dropped from queue after XXXms
```

**解決方法**:
```bash
# Docker コンテナの再起動
docker compose restart

# データベースの再作成
./scripts/setup_db.sh
```

### コンパイルエラー

#### モジュール再定義の警告

**症状**:
```
warning: redefining module ElixirCqrs.CategoryCommandService.Service
```

**解決方法**:
```bash
# ビルドキャッシュのクリア
rm -rf _build
mix deps.clean --all
mix deps.get
mix compile
```

#### 未定義関数エラー

**症状**:
```
** (UndefinedFunctionError) function Module.function/1 is undefined or private
```

**解決方法**:
1. 依存関係の更新
   ```bash
   mix deps.update --all
   ```

2. Proto ファイルの再コンパイル
   ```bash
   ./scripts/compile_proto.sh
   ```

### 実行時エラー

#### KeyError: key not found

**症状**:
```
** (KeyError) key :description not found
```

**原因**: データモデルとデータベーススキーマの不一致

**解決方法**:
```bash
# マイグレーションの実行
mix ecto.migrate

# または、データベースのリセット
mix ecto.reset
```

#### イベントストアエラー

**症状**:
```
{:error, :version_mismatch}
```

**原因**: 楽観的ロックの競合

**解決方法**:
- 同じアグリゲートに対する並行処理を避ける
- リトライロジックの実装

### パフォーマンス問題

#### GraphQL クエリが遅い

**確認事項**:
1. N+1 クエリの発生
   - Dataloader の使用を検討
   
2. インデックスの不足
   ```sql
   -- 必要なインデックスを追加
   CREATE INDEX ON products(category_id);
   CREATE INDEX ON products(created_at);
   ```

3. プロジェクションの遅延
   - ProjectionManager のポーリング間隔を調整

### 開発環境の問題

#### IEx でのデバッグ

```elixir
# プロセスの状態確認
:sys.get_state(ProcessName)

# 実行中のプロセス一覧
Process.list() |> Enum.map(&Process.info/1)

# メモリ使用量の確認
:erlang.memory()
```

#### ログレベルの変更

```elixir
# 実行時にログレベルを変更
Logger.configure(level: :debug)

# 特定モジュールのみデバッグ
Logger.put_module_level(MyModule, :debug)
```

### Docker 関連

#### コンテナが起動しない

```bash
# ログの確認
docker compose logs postgres-event-store
docker compose logs postgres-command
docker compose logs postgres-query

# コンテナの再構築
docker compose down -v
docker compose up -d --build
```

#### ディスク容量不足

```bash
# 不要なイメージとコンテナの削除
docker system prune -a
```

### 監視ツールの問題

#### Jaeger にトレースが表示されない

1. OTLP エクスポーターの設定確認
2. サービス名が正しく設定されているか確認
3. Jaeger UI でサービスドロップダウンを更新

#### Prometheus/Grafana にデータがない

1. メトリクスエンドポイントの確認
   ```bash
   curl http://localhost:4000/metrics
   ```

2. Prometheus のターゲット確認
   - http://localhost:9090/targets

### その他の問題

#### Proto ファイルのコンパイルエラー

```bash
# protoc のインストール確認
which protoc

# 手動でコンパイル
protoc --elixir_out=plugins=grpc:./apps/shared/lib/proto \
       --proto_path=./proto \
       ./proto/*.proto
```

#### 依存関係の競合

```bash
# 依存関係ツリーの表示
mix deps.tree

# 特定の依存関係の確認
mix deps | grep package_name
```

## サポート

問題が解決しない場合は、以下の情報を含めて issue を作成してください：

1. エラーメッセージの全文
2. 実行したコマンド
3. 環境情報（OS、Elixir バージョンなど）
4. 再現手順