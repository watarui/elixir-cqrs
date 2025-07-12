# pgweb の使い方

## アクセス
http://localhost:5050

## データベースの切り替え方法

pgweb では右上の「Connection」タブをクリックして、以下の接続情報を入力することで各データベースに接続できます。

**重要**: pgweb は Docker コンテナ内で動作しているため、Host には Docker サービス名を使用してください。

### 1. Event Store DB
- **Host**: `postgres-event-store`
- **Port**: `5432`
- **Database**: `elixir_cqrs_event_store_dev`
- **User**: `postgres`
- **Password**: `postgres`
- **SSL Mode**: `disable`

**主なテーブル**:
- `events` - すべてのドメインイベントを格納
- `sagas` - サガの状態を管理
- `snapshots` - アグリゲートのスナップショット

### 2. Command DB
- **Host**: `postgres-command`
- **Port**: `5432` （注意：コンテナ内部ポートは5432）
- **Database**: `elixir_cqrs_command_dev`
- **User**: `postgres`
- **Password**: `postgres`
- **SSL Mode**: `disable`

**主なテーブル**:
- `categories` - カテゴリの現在の状態
- `products` - 商品の現在の状態

### 3. Query DB
- **Host**: `postgres-query`
- **Port**: `5432` （注意：コンテナ内部ポートは5432）
- **Database**: `elixir_cqrs_query_dev`
- **User**: `postgres`
- **Password**: `postgres`
- **SSL Mode**: `disable`

**主なテーブル**:
- `categories` - 読み取り専用のカテゴリビュー
- `products` - 読み取り専用の商品ビュー
- `orders` - 読み取り専用の注文ビュー

## 接続方法

1. pgweb にアクセス (http://localhost:5050)
2. 右上の「Disconnect」ボタンをクリック（現在の接続を切断）
3. 接続フォームが表示されるので、上記の接続情報を入力
4. 「Connect」ボタンをクリック

## よく使うクエリ

### Event Store
```sql
-- 最新のイベントを10件表示
SELECT * FROM events ORDER BY id DESC LIMIT 10;

-- イベントタイプ別の集計
SELECT event_type, COUNT(*) FROM events GROUP BY event_type;
```

### Command DB
```sql
-- カテゴリ一覧
SELECT * FROM categories;

-- 商品一覧（カテゴリ情報付き）
SELECT p.*, c.name as category_name 
FROM products p 
LEFT JOIN categories c ON p.category_id = c.id;
```

### Query DB
```sql
-- 注文一覧（最新順）
SELECT * FROM orders ORDER BY created_at DESC;

-- カテゴリ別商品数
SELECT c.name, c.product_count FROM categories c;
```