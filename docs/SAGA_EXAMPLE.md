# SAGA 実行例

## SAGA パターンとは

SAGA パターンは、マイクロサービス環境で分散トランザクションを管理するパターンです。各ステップが成功した場合は次のステップに進み、失敗した場合は補償トランザクションでロールバックします。

## OrderSaga の実装

このプロジェクトでは、注文処理フローを SAGA パターンで実装しています。

### SAGA のステップ

1. **在庫予約** - 商品の在庫を予約
2. **支払い処理** - 支払いを実行
3. **注文確認** - 注文を確定

失敗時は逆順で補償処理を実行します。

## 実行手順

### 1. 事前準備

まず、カテゴリと商品を作成します。

```graphql
# カテゴリ作成
mutation {
  createCategory(input: { name: "電子機器", description: "電子機器カテゴリ" }) {
    id
    name
  }
}

# 商品作成（カテゴリIDを使用）
mutation {
  createProduct(
    input: {
      name: "スマートフォン"
      description: "最新モデル"
      price: 80000
      categoryId: "上で作成したカテゴリID"
      stockQuantity: 5
    }
  ) {
    id
    name
    stockQuantity
  }
}
```

### 2. 注文作成（SAGA 開始）

```graphql
mutation CreateOrder {
  createOrder(
    input: {
      userId: "user-123"
      items: [
        {
          productId: "上で作成した商品ID"
          productName: "スマートフォン"
          quantity: 2
          unitPrice: 80000
        }
      ]
    }
  ) {
    id
    status
    totalAmount
    items {
      productName
      quantity
      unitPrice
    }
  }
}
```

### 3. SAGA の実行フロー

#### 成功シナリオ

```
1. CreateOrder コマンド受信
   ↓
2. OrderCreated イベント発行
   ↓
3. OrderSaga 開始
   ↓
4. ReserveInventory コマンド送信
   ↓
5. InventoryReserved イベント受信
   ↓
6. ProcessPayment コマンド送信
   ↓
7. PaymentProcessed イベント受信
   ↓
8. ConfirmOrder コマンド送信
   ↓
9. OrderConfirmed イベント受信
   ↓
10. SAGA 完了
```

#### 失敗シナリオ（支払い失敗）

```
1-5. 在庫予約まで成功
   ↓
6. ProcessPayment コマンド送信
   ↓
7. PaymentFailed イベント受信
   ↓
8. 補償処理開始
   ↓
9. ReleaseInventory コマンド送信（在庫解放）
   ↓
10. CancelOrder コマンド送信
   ↓
11. SAGA 完了（注文キャンセル）
```

### 4. 実装コード

#### SAGA 定義

```elixir
defmodule CommandService.Domain.Sagas.OrderSaga do
  @behaviour Shared.Infrastructure.Saga.SagaBehaviour

  # SAGA のステップ定義
  def steps do
    [
      %Step{
        name: :reserve_inventory,
        handler: &reserve_inventory/2,
        compensation: &release_inventory/2
      },
      %Step{
        name: :process_payment,
        handler: &process_payment/2,
        compensation: &refund_payment/2
      },
      %Step{
        name: :confirm_order,
        handler: &confirm_order/2,
        compensation: nil
      }
    ]
  end

  # 各ステップの実装
  defp reserve_inventory(_saga_id, %{items: items} = data) do
    # 在庫予約コマンドを送信
    command = %ReserveInventory{
      order_id: data.order_id,
      items: items
    }

    EventBus.publish(:commands, command)
    {:ok, data}
  end

  defp process_payment(_saga_id, data) do
    # 支払い処理コマンドを送信
    command = %ProcessPayment{
      order_id: data.order_id,
      amount: data.total_amount,
      user_id: data.user_id
    }

    EventBus.publish(:commands, command)
    {:ok, data}
  end
end
```

### 5. 監視とデバッグ

#### Jaeger でトレースを確認

1. http://localhost:16686 にアクセス
2. Service で "command_service" を選択
3. Operation で "order_saga" を選択
4. トレースを確認

各ステップの実行時間と成功/失敗が可視化されます。

#### ログで確認

```bash
# SAGA の開始
[info] Starting saga 123e4567-e89b-12d3-a456-426614174000 with OrderSaga

# ステップの実行
[info] Executing step reserve_inventory for saga 123e4567-e89b-12d3-a456-426614174000

# 成功時
[info] Saga 123e4567-e89b-12d3-a456-426614174000 completed successfully

# 失敗時
[error] Step process_payment failed for saga 123e4567-e89b-12d3-a456-426614174000
[info] Starting compensation for saga 123e4567-e89b-12d3-a456-426614174000
```

## テストシナリオ

### 1. 正常系テスト

十分な在庫がある商品で注文を作成し、すべてのステップが成功することを確認。

### 2. 在庫不足テスト

在庫以上の数量で注文を作成し、SAGA が適切に失敗することを確認。

### 3. 支払い失敗テスト

特定の金額（例：999999）で注文を作成し、支払いステップで失敗させ、補償処理が実行されることを確認。

### 4. タイムアウトテスト

サービスを停止した状態で注文を作成し、タイムアウトが発生することを確認。

## トラブルシューティング

### SAGA が進まない場合

1. すべてのサービスが起動していることを確認
2. Phoenix PubSub の接続を確認
3. イベントストアのログを確認

### 補償処理が実行されない場合

1. SAGA の状態を確認

   ```sql
   SELECT * FROM sagas WHERE id = 'saga-id';
   ```

2. イベントログを確認
   ```sql
   SELECT * FROM events WHERE aggregate_id = 'order-id' ORDER BY created_at;
   ```

### パフォーマンスの問題

1. Jaeger でボトルネックを特定
2. 各ステップのタイムアウト設定を調整
3. 並列実行可能なステップを識別
