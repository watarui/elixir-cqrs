# pgAdmin 使用ガイド

pgAdmin は PostgreSQL データベースを管理するための Web ベースの GUI ツールです。本プロジェクトでは、3つのデータベース（Event Store、Command DB、Query DB）を管理するために使用します。

## アクセス方法

1. Docker Compose でサービスを起動：
   ```bash
   docker compose up -d pgadmin
   ```

2. ブラウザで以下の URL にアクセス：
   ```
   http://localhost:5050
   ```

3. ログイン情報：
   - Email: `admin@example.com`
   - Password: `admin`

## 事前設定されたデータベース

初回起動時、以下の3つのデータベース接続が自動的に設定されています：

### 1. Event Store DB
- 接続名: Event Store DB
- ホスト: postgres-event-store
- ポート: 5432
- データベース: elixir_cqrs_event_store_dev

### 2. Command DB
- 接続名: Command DB
- ホスト: postgres-command
- ポート: 5432
- データベース: elixir_cqrs_command_dev

### 3. Query DB
- 接続名: Query DB
- ホスト: postgres-query
- ポート: 5432
- データベース: elixir_cqrs_query_dev

すべてのデータベースのログイン情報：
- ユーザー名: postgres
- パスワード: postgres

## 主な機能

### データベースの探索
1. 左側のツリーから「CQRS Databases」グループを展開
2. 確認したいデータベースを選択
3. スキーマ → public → Tables でテーブル一覧を確認

### テーブルのレコード確認方法
1. **GUI で確認する方法**
   - 左側のツリーでテーブルを探す（例：Events DB → Schemas → public → Tables → events）
   - テーブルを右クリック
   - 「View/Edit Data」→「All Rows」を選択
   - データがグリッド形式で表示されます
   - 列の並び替え、フィルタリング、編集が可能

2. **クイックアクション**
   - テーブルを右クリック → 「View/Edit Data」
   - 「First 100 Rows」: 最初の100行を表示
   - 「Last 100 Rows」: 最後の100行を表示
   - 「Filtered Rows」: 条件を指定してデータを表示

### SQL クエリの実行
1. データベースを右クリック → Query Tool を選択
2. SQL エディタでクエリを記述
3. F5 キーまたは実行ボタン（▶）でクエリを実行
4. 結果は下部のグリッドに表示

### pgAdmin のショートカットキー
- **F5**: クエリ実行
- **Ctrl+/**: 選択行のコメント/アンコメント
- **Ctrl+Space**: オートコンプリート
- **F7**: Explain Plan の表示
- **Alt+Shift+F**: SQL のフォーマット

### よく使うクエリ例

#### Event Store のイベント確認
```sql
-- 最新のイベントを確認
SELECT * FROM events ORDER BY event_id DESC LIMIT 10;

-- 特定の aggregate のイベント履歴
SELECT * FROM events 
WHERE aggregate_id = 'your-aggregate-id' 
ORDER BY sequence_number;
```

#### Command DB の Saga 状態確認
```sql
-- アクティブな Saga を確認
SELECT * FROM sagas WHERE status = 'active';

-- Saga の実行履歴
SELECT * FROM saga_executions ORDER BY created_at DESC LIMIT 20;
```

#### Query DB のプロジェクション確認
```sql
-- 商品リスト
SELECT * FROM products;

-- 注文リスト
SELECT * FROM orders ORDER BY created_at DESC;
```

## トラブルシューティング

### パスワードが要求される場合
初回接続時にパスワードの入力を求められた場合は、`postgres` と入力してください。

### 接続できない場合
1. すべての PostgreSQL コンテナが起動していることを確認：
   ```bash
   docker compose ps
   ```

2. ネットワークの確認：
   ```bash
   docker network ls | grep elixir-cqrs
   ```

### データが表示されない場合
デモデータを投入していない場合は、以下のコマンドでデータを投入：
```bash
./scripts/start_all.sh --with-demo-data
```

## セキュリティに関する注意

- デフォルトの認証情報は開発環境用です
- 本番環境では必ず強力なパスワードに変更してください
- pgAdmin の設定ファイル（pgpass）は .gitignore に含まれています