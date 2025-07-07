# サガパターン実装ガイド

## 概要

サガパターンは、マイクロサービス環境における分散トランザクションを管理するためのパターンです。長時間実行されるビジネスプロセスを、一連の補償可能なトランザクションに分解します。

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────┐
│                   Saga Coordinator                       │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │Saga Manager │  │Event Handler │  │Command Dispatch│ │
│  └──────┬──────┘  └───────┬──────┘  └────────┬───────┘ │
└─────────┼─────────────────┼──────────────────┼─────────┘
          │                 │                  │
          ▼                 ▼                  ▼
    ┌───────────┐    ┌────────────┐    ┌──────────────┐
    │Event Store│    │ Event Bus  │    │Command Bus   │
    └───────────┘    └────────────┘    └──────────────┘
          │                 │                  │
    ┌─────┴─────┬──────────┴──────────┬───────┴────────┐
    ▼           ▼                      ▼                ▼
┌────────┐ ┌────────┐           ┌──────────┐    ┌──────────┐
│Service1│ │Service2│           │Service3  │    │Service4  │
└────────┘ └────────┘           └──────────┘    └──────────┘
```

## コア概念

### 1. サガの状態

```elixir
@type saga_state :: 
  :started |        # 開始済み
  :processing |     # 処理中
  :compensating |   # 補償処理中
  :completed |      # 完了
  :failed |         # 失敗
  :compensated      # 補償完了
```

### 2. サガのライフサイクル

```
開始 → 処理中 → 完了
         ↓
       失敗 → 補償中 → 補償完了
```

## 実装例：注文処理サガ

### サガの定義

```elixir
defmodule OrderSaga do
  use Shared.Domain.Saga.SagaBase
  
  # サガのステップ
  # 1. 在庫予約
  # 2. 支払い処理
  # 3. 配送手配
  # 4. 注文確定
  
  def handle_event(event, saga) do
    case {event.event_type, saga.state} do
      {"saga_started", :started} ->
        # 最初のコマンドを発行
        {:ok, [ReserveInventoryCommand.new(...)]}
        
      {"inventory_reserved", :started} ->
        # 次のステップへ
        {:ok, [ProcessPaymentCommand.new(...)]}
        
      {"payment_failed", _} ->
        # 失敗 - 補償処理を開始
        {:error, "Payment failed"}
        
      # ... 他のイベント処理
    end
  end
  
  def get_compensation_commands(saga) do
    # 完了したステップを逆順に補償
    [
      ReleaseInventoryCommand.new(...),
      RefundPaymentCommand.new(...),
      CancelOrderCommand.new(...)
    ]
  end
end
```

### サガの開始

```elixir
# GraphQLリゾルバーから
def create_order(_parent, %{input: input}, _context) do
  # 注文を作成
  {:ok, order} = create_order_aggregate(input)
  
  # サガを開始
  {:ok, saga_id} = SagaCoordinator.start_saga(
    OrderSaga,
    %{
      order_id: order.id,
      customer_id: input.customer_id,
      items: input.items,
      total_amount: calculate_total(input.items)
    }
  )
  
  {:ok, order}
end
```

## 補償トランザクション

### 補償可能なコマンドの設計

```elixir
# 実行コマンド
defmodule ReserveInventoryCommand do
  # 在庫を予約
end

# 補償コマンド
defmodule ReleaseInventoryCommand do
  # 予約した在庫を解放
end
```

### 補償の実行順序

補償は完了したステップの**逆順**で実行されます：

```
実行順: A → B → C → 失敗
補償順: C → B → A
```

## イベント駆動の統合

### イベントの流れ

1. **ドメインイベント** → SagaEventHandler
2. **SagaEventHandler** → SagaCoordinator
3. **SagaCoordinator** → CommandDispatcher
4. **CommandDispatcher** → 各サービス
5. **各サービス** → ドメインイベント（ループ）

### イベントとコマンドのマッピング

```elixir
# イベント → 次のコマンド
"inventory_reserved" → ProcessPaymentCommand
"payment_processed" → ArrangeShippingCommand
"shipping_arranged" → ConfirmOrderCommand

# 失敗イベント → 補償開始
"inventory_reservation_failed" → 補償処理開始
"payment_failed" → 補償処理開始
```

## 監視とデバッグ

### メトリクス

```elixir
# 利用可能なメトリクス
saga.started.count        # 開始されたサガ数
saga.completed.count      # 完了したサガ数
saga.failed.count         # 失敗したサガ数
saga.compensation.count   # 補償実行数
saga.duration            # 実行時間
saga.active.count        # アクティブなサガ数
```

### ログ

```json
{
  "level": "info",
  "message": "Started new saga",
  "saga_type": "OrderSaga",
  "saga_id": "123e4567-e89b-12d3-a456-426614174000",
  "trigger_event": "order_created"
}
```

### サガの状態確認

```elixir
# 特定のサガの状態を取得
{:ok, saga} = SagaCoordinator.get_saga(saga_id)

# アクティブなサガ一覧
sagas = SagaCoordinator.list_active_sagas()
```

## ベストプラクティス

### 1. サガの設計

- **小さく保つ**: 各サガは単一のビジネスプロセスに焦点を当てる
- **タイムアウト設定**: 長時間実行を防ぐ
- **冪等性**: コマンドとイベントハンドラーは冪等であるべき

### 2. エラーハンドリング

```elixir
def handle_event(event, saga) do
  try do
    # 処理実行
  rescue
    e in [RuntimeError, ArgumentError] ->
      # 回復可能なエラー
      {:error, Exception.message(e)}
  catch
    :exit, reason ->
      # 致命的エラー
      {:error, {:fatal, reason}}
  end
end
```

### 3. テスト戦略

```elixir
defmodule OrderSagaTest do
  use ExUnit.Case
  
  test "完全な成功シナリオ" do
    saga = OrderSaga.start("test-id", initial_data)
    
    # 各ステップをシミュレート
    {:ok, commands} = OrderSaga.handle_event(
      %{event_type: "inventory_reserved"},
      saga
    )
    
    assert length(commands) == 1
    assert %ProcessPaymentCommand{} = hd(commands)
  end
  
  test "補償シナリオ" do
    saga = %{failed_saga | 
      inventory_reserved: true,
      payment_processed: true
    }
    
    commands = OrderSaga.get_compensation_commands(saga)
    
    assert [
      %RefundPaymentCommand{},
      %ReleaseInventoryCommand{},
      %CancelOrderCommand{}
    ] = commands
  end
end
```

## トラブルシューティング

### よくある問題

1. **サガが完了しない**
   - タイムアウト設定を確認
   - イベントハンドラーのエラーを確認
   - デッドレターキューをチェック

2. **補償が実行されない**
   - 補償コマンドの実装を確認
   - イベントの発行を確認
   - ログでエラーを確認

3. **重複実行**
   - イベントの冪等性を確認
   - 処理済みイベントの追跡を確認

### デバッグ手順

```elixir
# 1. サガの履歴を確認
{:ok, events} = SagaRepository.get_saga_history(saga_id)

# 2. 現在の状態を確認
{:ok, saga} = SagaCoordinator.get_saga(saga_id)
IO.inspect(saga, label: "Current saga state")

# 3. ログを確認
Logger.configure(level: :debug)
```

## 拡張ポイント

### カスタムサガの作成

1. `Shared.Domain.Saga.SagaBase`を使用
2. 必要なコールバックを実装
3. SagaEventHandlerにトリガーを登録
4. テストを作成

### 永続化の拡張

- PostgreSQL以外のストレージ対応
- スナップショット戦略のカスタマイズ
- アーカイブポリシーの実装

### 監視の強化

- カスタムメトリクスの追加
- アラートルールの設定
- ダッシュボードの作成