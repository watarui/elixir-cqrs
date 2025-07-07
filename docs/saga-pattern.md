# サガパターン実装ガイド

## 概要

サガパターンは、マイクロサービス環境での分散トランザクション管理を実現するデザインパターンです。このプロジェクトでは、注文処理フローにサガパターンを適用し、複数のサービス間でのデータ整合性を保証しています。

## サガパターンとは

サガは、一連のローカルトランザクションのシーケンスです。各ローカルトランザクションは対応するサービスのデータを更新し、次のローカルトランザクションをトリガーするメッセージまたはイベントを発行します。いずれかのローカルトランザクションが失敗した場合、サガは補償トランザクションを実行して、以前のトランザクションで行われた変更を元に戻します。

### 利点

- **疎結合**: 各サービスは独立して動作し、他のサービスの実装詳細を知る必要がありません
- **スケーラビリティ**: 各サービスは独立してスケールできます
- **障害分離**: 一部のサービスが停止しても、補償処理により整合性を保てます
- **可観測性**: 各ステップのログとメトリクスを収集しやすい

### 欠点

- **複雑性**: 補償ロジックの実装が必要
- **デバッグの困難さ**: 分散システムのデバッグは難しい
- **結果整合性**: 即座の整合性は保証されない

## 実装アーキテクチャ

### サガフロー図

```
┌─────────────┐
│Create Order │
└──────┬──────┘
       │
   ┌───▼───┐     Success      ┌──────────────┐
   │Reserve├─────────────────▶│Process       │
   │Stock  │                  │Payment       │
   └───┬───┘                  └──────┬───────┘
       │ Fail                        │ Success
       │                             │
   ┌───▼───────┐              ┌──────▼───────┐
   │Compensate │              │Arrange       │
   │(Cancel)   │              │Shipping      │
   └───────────┘              └──────┬───────┘
                                     │
                              ┌──────▼───────┐
                              │Confirm Order │
                              └──────────────┘
```

### 主要コンポーネント

#### 1. SagaCoordinator

サガ全体の実行を管理するコンポーネントです。

```elixir
defmodule CommandService.Domain.Sagas.SagaCoordinator do
  @moduledoc """
  サガパターンのコーディネーター
  """

  def start_saga(saga_type, params) do
    # サガの初期化
    saga_id = generate_saga_id()
    initial_state = create_initial_state(saga_type, params)

    # 最初のステップを実行
    execute_next_step(saga_id, initial_state)
  end

  def handle_step_result(saga_id, step_result) do
    # ステップの結果を処理し、次のアクションを決定
  end
end
```

#### 2. OrderSaga

注文処理の具体的なサガ実装です。

```elixir
defmodule CommandService.Domain.Sagas.OrderSaga do
  @moduledoc """
  注文処理のサガ実装
  """

  @behaviour CommandService.Domain.Sagas.SagaBehaviour

  def steps do
    [
      {:reserve_inventory, &reserve_inventory/1, &cancel_reservation/1},
      {:process_payment, &process_payment/1, &refund_payment/1},
      {:arrange_shipping, &arrange_shipping/1, &cancel_shipping/1},
      {:confirm_order, &confirm_order/1, nil}
    ]
  end
end
```

### ステップの詳細

#### 1. 在庫予約 (Reserve Inventory)

**責任**: 注文された商品の在庫を予約する

**成功条件**:

- すべての商品の在庫が十分にある
- 在庫の予約が正常に記録される

**失敗時の処理**:

- サガを中止し、注文をキャンセル

**補償トランザクション**:

- 予約した在庫を解放

#### 2. 決済処理 (Process Payment)

**責任**: 顧客の支払い方法で決済を行う

**成功条件**:

- 決済が承認される
- 支払いトランザクションが記録される

**失敗時の処理**:

- 在庫予約を解放
- 注文をキャンセル

**補償トランザクション**:

- 決済を返金処理

#### 3. 配送手配 (Arrange Shipping)

**責任**: 配送業者に配送を依頼する

**成功条件**:

- 配送業者が配送を受理
- 配送追跡番号が発行される

**失敗時の処理**:

- 決済を返金
- 在庫予約を解放
- 注文をキャンセル

**補償トランザクション**:

- 配送をキャンセル

#### 4. 注文確定 (Confirm Order)

**責任**: 注文を最終的に確定し、顧客に通知する

**成功条件**:

- 注文ステータスが確定に更新される
- 顧客への通知が送信される

**失敗時の処理**:

- この時点での失敗は稀だが、ログに記録し、手動介入を促す

## 実装詳細

### サガステートの管理

```elixir
defmodule CommandService.Domain.Sagas.SagaState do
  defstruct [
    :saga_id,
    :saga_type,
    :current_step,
    :completed_steps,
    :state,  # :started, :running, :completed, :failed, :compensating
    :context,
    :error,
    :started_at,
    :completed_at
  ]
end
```

### イベント駆動の実装

各ステップの完了はイベントとして記録され、次のステップのトリガーとなります。

```elixir
defmodule CommandService.Domain.Events.SagaEvents do
  defmodule SagaStarted do
    defstruct [:saga_id, :saga_type, :initial_context, :timestamp]
  end

  defmodule StepCompleted do
    defstruct [:saga_id, :step_name, :result, :timestamp]
  end

  defmodule StepFailed do
    defstruct [:saga_id, :step_name, :error, :timestamp]
  end

  defmodule SagaCompleted do
    defstruct [:saga_id, :final_result, :timestamp]
  end

  defmodule CompensationStarted do
    defstruct [:saga_id, :failed_step, :timestamp]
  end
end
```

### エラーハンドリング

```elixir
defmodule CommandService.Domain.Sagas.ErrorHandler do
  def handle_step_failure(saga_state, failed_step, error) do
    case error do
      {:temporary_failure, _reason} ->
        # リトライ可能なエラー
        schedule_retry(saga_state, failed_step)

      {:permanent_failure, _reason} ->
        # リトライ不可能なエラー
        start_compensation(saga_state, failed_step)

      _ ->
        # 予期しないエラー
        log_and_alert(saga_state, error)
        start_compensation(saga_state, failed_step)
    end
  end
end
```

## GraphQL API

### 注文作成ミューテーション

```graphql
mutation CreateOrder {
  createOrder(
    input: { userId: "user-123", items: [{ productId: "1", quantity: 2 }] }
  ) {
    id
    status
    sagaState {
      state
      currentStep
      completedSteps
      startedAt
      completedAt
      failureReason
    }
  }
}
```

### サガステータスクエリ

```graphql
query GetSagaStatus {
  sagaStatus(orderId: "order-123") {
    sagaId
    state
    currentStep
    completedSteps
    error
    startedAt
    completedAt
  }
}
```

## 監視とデバッグ

### メトリクス

- `saga_started_total`: 開始されたサガの総数
- `saga_completed_total`: 完了したサガの総数
- `saga_failed_total`: 失敗したサガの総数
- `saga_duration_seconds`: サガの実行時間
- `saga_step_duration_seconds`: 各ステップの実行時間

### ログ

構造化ログにより、サガの実行を追跡できます：

```json
{
  "level": "info",
  "message": "Saga step completed",
  "saga_id": "saga-123",
  "step": "reserve_inventory",
  "duration_ms": 150,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### 分散トレーシング

OpenTelemetry と Jaeger を使用して、サガの実行フローを可視化：

```
[Client] ──> [GraphQL] ──> [CommandService] ──> [InventoryService]
                              │                      │
                              │                      └──> [Database]
                              │
                              └──> [PaymentService] ──> [Payment Gateway]
```

## ベストプラクティス

### 1. べき等性の確保

各ステップは複数回実行されても同じ結果になるよう設計します。

```elixir
def reserve_inventory(context) do
  # べき等性キーを使用
  idempotency_key = "reserve-#{context.order_id}"

  case check_existing_reservation(idempotency_key) do
    {:ok, existing} -> {:ok, existing}
    {:error, :not_found} -> perform_reservation(context, idempotency_key)
  end
end
```

### 2. タイムアウトの設定

各ステップに適切なタイムアウトを設定します。

```elixir
@step_timeout 30_000  # 30秒

def execute_step(step_fn, context) do
  task = Task.async(fn -> step_fn.(context) end)

  case Task.yield(task, @step_timeout) || Task.shutdown(task) do
    {:ok, result} -> result
    nil -> {:error, :timeout}
  end
end
```

### 3. 補償トランザクションの設計

補償処理も失敗する可能性を考慮します。

```elixir
def compensate_with_retry(compensation_fn, context, max_retries \\ 3) do
  Enum.reduce_while(1..max_retries, {:error, :init}, fn attempt, _acc ->
    case compensation_fn.(context) do
      {:ok, _} = success ->
        {:halt, success}
      {:error, reason} ->
        if attempt < max_retries do
          Process.sleep(attempt * 1000)  # エクスポネンシャルバックオフ
          {:cont, {:error, reason}}
        else
          {:halt, {:error, {:compensation_failed, reason}}}
        end
    end
  end)
end
```

### 4. サガの状態永続化

サガの状態は永続化し、システム障害後も継続できるようにします。

```elixir
def persist_saga_state(saga_state) do
  EventStore.append_to_stream(
    "saga-#{saga_state.saga_id}",
    [%SagaStateUpdated{state: saga_state}]
  )
end
```

## トラブルシューティング

### よくある問題

#### 1. サガが途中で停止する

**原因**:

- ネットワークエラー
- サービスの一時的な停止
- タイムアウト

**対処法**:

```bash
# サガの状態を確認
mix saga.status saga-123

# 手動でサガを再開
mix saga.resume saga-123
```

#### 2. 補償処理が失敗する

**原因**:

- 補償対象のリソースが既に変更されている
- 補償処理自体のバグ

**対処法**:

- 補償処理のログを確認
- 必要に応じて手動介入

#### 3. デッドロック

**原因**:

- 複数のサガが同じリソースに同時アクセス

**対処法**:

- リソースアクセス順序の統一
- 楽観的ロックの使用

## 今後の改善点

### 1. サガの並列実行

現在は各ステップが順次実行されますが、独立したステップは並列実行可能です。

```
         ┌─> Reserve Inventory ─┐
Start ───┤                      ├─> Confirm Order
         └─> Process Payment ───┘
```

### 2. サガのバージョニング

実行中のサガがある状態でのデプロイを考慮したバージョニング戦略。

### 3. サガの可視化ツール

現在のサガの状態をリアルタイムで可視化するダッシュボード。

### 4. 自動リカバリー

一時的な障害からの自動回復機能の強化。

## 参考資料

- [Microservices.io - Saga Pattern](https://microservices.io/patterns/data/saga.html)
- [Chris Richardson - Sagas](https://chrisrichardson.net/post/antipatterns/2019/07/09/developing-sagas-part-1.html)
- [Microsoft - Saga distributed transactions pattern](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)
