# gRPCレジリエンス機能

## 概要

このプロジェクトでは、gRPC通信の信頼性を向上させるために、以下のレジリエンスパターンを実装しています：

1. **リトライ戦略** - 一時的な障害に対する自動再試行
2. **サーキットブレーカー** - 連続的な障害からシステムを保護
3. **タイムアウト管理** - 応答しないサービスからの保護
4. **包括的な監視** - すべての試行と障害の追跡

## アーキテクチャ

```
┌─────────────────┐
│ GraphQL Client  │
└────────┬────────┘
         │
┌────────▼────────┐
│  GraphQL API    │
│ (Client Service)│
└────────┬────────┘
         │
┌────────▼────────────┐
│ ResilientClient     │
├─────────────────────┤
│ • Timeout Control   │
│ • Retry Logic       │
│ • Circuit Breaker   │
│ • Metrics & Logging │
└────────┬────────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼────┐
│Command│ │ Query │
│Service│ │Service│
└───────┘ └───────┘
```

## リトライ戦略

### 機能

- **エクスポネンシャルバックオフ**: 再試行間隔を徐々に増やす
- **ジッター**: 同時再試行を防ぐためのランダム化
- **選択的リトライ**: 特定のエラーのみ再試行
- **設定可能**: 操作ごとに異なる戦略

### 設定

```elixir
# config/resilience.exs
config :shared, :grpc_retry,
  default: %{
    max_attempts: 3,          # 最大試行回数
    initial_delay: 100,       # 初回遅延（ミリ秒）
    max_delay: 5000,          # 最大遅延（ミリ秒）
    multiplier: 2.0,          # 遅延の乗数
    jitter: true,             # ジッターの有効化
    retryable_errors: [       # リトライ可能なエラー
      :unavailable,
      :deadline_exceeded,
      :resource_exhausted,
      :aborted,
      :internal
    ]
  }
```

### 使用例

```elixir
ResilientClient.call(
  fn -> Query.ProductQuery.Stub.get_product(channel, request) end,
  %{
    retry: %{
      max_attempts: 3,
      initial_delay: 200
    }
  }
)
```

## サーキットブレーカー

### 状態遷移

```
        失敗閾値到達
CLOSED ─────────────► OPEN
  ▲                     │
  │                     │ タイムアウト後
  │                     ▼
  └──────────────── HALF_OPEN
      成功閾値到達      │
                       │ 失敗
                       ▼
                     OPEN
```

### 設定

```elixir
# config/resilience.exs
config :shared, :circuit_breakers,
  command_service: %{
    failure_threshold: 5,     # Open状態への失敗数
    success_threshold: 2,     # Closed状態への成功数
    timeout: 30_000,          # Half-Open状態への待機時間
    reset_timeout: 60_000     # 自動リセット時間
  }
```

### 状態確認

```elixir
# サーキットブレーカーの状態を確認
GrpcConnections.get_circuit_breaker_status()
# => %{command: :closed, query: :half_open}

# サーキットブレーカーをリセット
GrpcConnections.reset_circuit_breakers()
```

## タイムアウト管理

### 操作別タイムアウト

```elixir
# config/resilience.exs
config :shared, :grpc_timeouts,
  default: 5000,
  operations: %{
    list_products: 10000,    # 一覧取得は長め
    get_product: 3000,       # 単一取得は短め
    create_product: 5000     # 書き込みは中間
  }
```

## 監視とメトリクス

### 収集されるメトリクス

1. **リトライメトリクス**
   - `grpc.retry.count` - リトライ回数
   - `grpc.retry.duration` - リトライにかかった時間

2. **サーキットブレーカーメトリクス**
   - `circuit_breaker.call.count` - 呼び出し回数（状態別）
   - `circuit_breaker.call.latency` - レイテンシ

3. **クライアント呼び出しメトリクス**
   - `grpc.client.call.count` - 成功/失敗数
   - `grpc.client.call.duration` - 全体の実行時間

### ログ出力

```json
{
  "level": "warning",
  "message": "gRPC call failed with unavailable, retrying in 200ms (attempt 1/3)",
  "error": "service unavailable"
}

{
  "level": "warning",
  "message": "Circuit breaker opening after 5 failures"
}
```

## トラブルシューティング

### よくある問題

1. **サーキットブレーカーが開いたまま**
   ```elixir
   # 手動リセット
   CircuitBreaker.reset(:query_service_cb)
   ```

2. **リトライが多すぎる**
   - `max_attempts`を減らす
   - `retryable_errors`を調整

3. **タイムアウトが頻発**
   - ネットワーク遅延を確認
   - タイムアウト値を増やす
   - サービスの負荷を確認

### デバッグ

```elixir
# ログレベルを上げる
Logger.configure(level: :debug)

# 特定のサーキットブレーカーの状態を監視
:timer.tc(fn ->
  Enum.each(1..10, fn _ ->
    IO.inspect(CircuitBreaker.get_state(:query_service_cb))
    Process.sleep(1000)
  end)
end)
```

## ベストプラクティス

1. **適切なタイムアウト設定**
   - 操作の性質に応じて調整
   - ネットワーク遅延を考慮

2. **リトライ戦略の選択**
   - 読み取り操作：少ない試行回数
   - 書き込み操作：慎重に（冪等性を確保）

3. **サーキットブレーカーの調整**
   - 本番環境の障害パターンに基づいて調整
   - 早すぎるOpen状態への遷移を避ける

4. **監視とアラート**
   - サーキットブレーカーのOpen状態をアラート
   - リトライ率の異常な上昇を監視

## 今後の改善計画

1. **適応的リトライ**
   - 成功率に基づいて動的に調整

2. **バルクヘッドパターン**
   - リソース分離による障害の封じ込め

3. **ヘルスチェック統合**
   - プロアクティブな障害検出

4. **分散トレーシング強化**
   - リトライとサーキットブレーカーの詳細な追跡