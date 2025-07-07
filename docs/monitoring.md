# 監視とログ収集

## 概要

このプロジェクトでは、以下のツールを使用して包括的な監視とログ収集を実現しています：

- **OpenTelemetry**: 分散トレーシングとメトリクス収集
- **Jaeger**: トレースの可視化
- **Prometheus**: メトリクス収集とアラート
- **Grafana**: ダッシュボードとビジュアライゼーション
- **構造化ログ**: JSON形式のログ出力

## セットアップ

### 1. 監視インフラの起動

```bash
docker compose -f docker-compose.monitoring.yml up -d
```

### 2. アクセスURL

- **Jaeger UI**: http://localhost:16686
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

## 分散トレーシング

### OpenTelemetryの設定

各サービスは自動的にOpenTelemetryを初期化し、以下をトレースします：

- HTTPリクエスト（Phoenix）
- GraphQLオペレーション（Absinthe）
- データベースクエリ（Ecto）
- gRPC通信
- カスタムビジネスオペレーション

### カスタムスパンの追加

```elixir
require Shared.Telemetry.Span, as: Span

Span.with_span "custom.operation", %{user_id: user_id} do
  # 処理を実行
end
```

## メトリクス

### 収集されるメトリクス

#### システムメトリクス
- CPU使用率
- メモリ使用量
- プロセス数
- ランキューの長さ

#### HTTPメトリクス
- リクエスト数（メソッド、パス、ステータス別）
- レスポンスタイム分布
- エラー率

#### GraphQLメトリクス
- オペレーション実行数（タイプ別）
- レゾルバー実行時間
- エラー率

#### データベースメトリクス
- クエリ実行数
- クエリ実行時間
- コネクションプール使用率

#### ビジネスメトリクス
- コマンド実行数（タイプ、成功/失敗別）
- イベント発行数（タイプ別）
- 商品・カテゴリの作成/更新/削除数

### カスタムメトリクスの追加

```elixir
# カウンター
Shared.Telemetry.Setup.record_business_event(:order_placed, %{
  user_id: user_id,
  amount: amount
})

# 値の記録
Shared.Telemetry.Setup.record_metric(:cart_size, items_count, %{
  user_id: user_id
})
```

## 構造化ログ

### ログ形式

すべてのログはJSON形式で出力されます：

```json
{
  "level": "info",
  "message": "Command executed successfully",
  "timestamp": "2024-01-20T10:30:45.123Z",
  "metadata": {
    "command_type": "CreateProduct",
    "aggregate_id": "123e4567-e89b-12d3-a456-426614174000",
    "duration_ms": 45
  }
}
```

### ログレベル

- **debug**: 詳細なデバッグ情報
- **info**: 通常の操作情報
- **warning**: 警告（処理は継続）
- **error**: エラー（処理失敗）

## アラート設定

### Prometheusアラートルール例

```yaml
groups:
  - name: elixir_cqrs_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(phoenix_endpoint_stop_count{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          
      - alert: SlowResponseTime
        expr: histogram_quantile(0.95, rate(phoenix_endpoint_stop_duration_bucket[5m])) > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "95th percentile response time > 1s"
```

## Grafanaダッシュボード

### 推奨ダッシュボード

1. **システム概要**
   - リクエスト率
   - エラー率
   - レスポンスタイム（p50, p95, p99）
   - アクティブユーザー数

2. **マイクロサービス健全性**
   - 各サービスのステータス
   - gRPC通信成功率
   - サービス間レイテンシ

3. **ビジネスメトリクス**
   - コマンド実行数
   - イベント発行率
   - エンティティ操作統計

## トラブルシューティング

### トレースが表示されない場合

1. Jaegerが起動していることを確認
2. OTLP エンドポイントが正しく設定されているか確認
3. サンプリング率を確認（開発環境では100%推奨）

### メトリクスが収集されない場合

1. Prometheusターゲットのステータスを確認
2. `/metrics`エンドポイントにアクセス可能か確認
3. ファイアウォール設定を確認

### ログが構造化されていない場合

1. LoggerJSON設定が正しく適用されているか確認
2. 環境変数`MIX_ENV`が正しく設定されているか確認