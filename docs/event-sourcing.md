# イベントソーシングガイド

## 概要

イベントソーシングは、アプリケーションの状態変更をイベントのシーケンスとして保存するデータ管理パターンです。従来の CRUD アプローチとは異なり、データの現在の状態だけでなく、その状態に至るまでのすべての変更履歴を保持します。

## イベントソーシングの基本概念

### イベントとは

イベントは、システム内で発生した事実を表す不変のレコードです。

```elixir
defmodule CommandService.Domain.Events.ProductCreated do
  @derive Jason.Encoder
  defstruct [
    :product_id,
    :name,
    :price,
    :category_id,
    :created_at
  ]
end
```

### イベントの特徴

1. **不変性（Immutable）**: 一度作成されたイベントは変更されない
2. **過去形の命名**: "ProductCreated"、"OrderPlaced"など
3. **ビジネスの意図を表現**: 技術的な詳細ではなくビジネス上の出来事
4. **自己完結**: イベント単体で意味が理解できる

## アーキテクチャ

### イベントストアの構造

```sql
-- イベントテーブル
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  aggregate_id UUID NOT NULL,
  aggregate_type VARCHAR(255) NOT NULL,
  event_type VARCHAR(255) NOT NULL,
  event_data JSONB NOT NULL,
  event_metadata JSONB,
  event_version INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  UNIQUE(aggregate_id, event_version)
);

-- インデックス
CREATE INDEX idx_events_aggregate_id ON events(aggregate_id);
CREATE INDEX idx_events_aggregate_type ON events(aggregate_type);
CREATE INDEX idx_events_created_at ON events(created_at);
```

### イベントフロー

```
1. コマンド受信
   ↓
2. アグリゲート再構築
   ↓
3. ビジネスロジック実行
   ↓
4. イベント生成
   ↓
5. イベントストアに保存
   ↓
6. プロジェクション更新
   ↓
7. 読み取りモデル更新
```

## 実装詳細

### アグリゲート基底クラス

```elixir
defmodule Shared.Domain.Aggregate do
  @moduledoc """
  イベントソーシングアグリゲートの基底モジュール
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Shared.Domain.Aggregate

      # アグリゲートの初期状態
      def initial_state, do: %{}

      # イベントからアグリゲートを再構築
      def load_from_events(events) do
        Enum.reduce(events, initial_state(), fn event, state ->
          apply_event(state, event)
        end)
      end

      # コマンドの実行
      def execute(state, command) do
        case handle_command(state, command) do
          {:ok, events} when is_list(events) ->
            new_state = Enum.reduce(events, state, &apply_event(&2, &1))
            {:ok, events, new_state}

          {:error, reason} ->
            {:error, reason}
        end
      end

      # オーバーライド可能な関数
      def handle_command(_state, _command), do: {:error, :not_implemented}
      def apply_event(state, _event), do: state

      defoverridable [initial_state: 0, handle_command: 2, apply_event: 2]
    end
  end
end
```

### 具体的なアグリゲート実装

```elixir
defmodule CommandService.Domain.Aggregates.Product do
  use Shared.Domain.Aggregate

  alias CommandService.Domain.Commands, as: Cmd
  alias CommandService.Domain.Events, as: Evt

  # アグリゲートの状態定義
  defstruct [
    :id,
    :name,
    :price,
    :category_id,
    :stock,
    :status,
    :version
  ]

  @impl true
  def initial_state, do: %__MODULE__{}

  @impl true
  def handle_command(%{id: nil}, %Cmd.CreateProduct{} = cmd) do
    event = %Evt.ProductCreated{
      product_id: UUID.uuid4(),
      name: cmd.name,
      price: cmd.price,
      category_id: cmd.category_id,
      created_at: DateTime.utc_now()
    }
    {:ok, [event]}
  end

  def handle_command(%{id: id}, %Cmd.UpdatePrice{} = cmd) when not is_nil(id) do
    if cmd.new_price > 0 do
      event = %Evt.PriceUpdated{
        product_id: id,
        old_price: state.price,
        new_price: cmd.new_price,
        updated_at: DateTime.utc_now()
      }
      {:ok, [event]}
    else
      {:error, :invalid_price}
    end
  end

  @impl true
  def apply_event(state, %Evt.ProductCreated{} = event) do
    %{state |
      id: event.product_id,
      name: event.name,
      price: event.price,
      category_id: event.category_id,
      status: :active,
      version: 1
    }
  end

  def apply_event(state, %Evt.PriceUpdated{} = event) do
    %{state |
      price: event.new_price,
      version: state.version + 1
    }
  end
end
```

### イベントストアの実装

```elixir
defmodule Shared.Infrastructure.EventStore do
  @moduledoc """
  PostgreSQLベースのイベントストア実装
  """

  alias Shared.Infrastructure.EventStore.Repo
  alias Shared.Infrastructure.EventStore.Event

  def append_events(aggregate_id, aggregate_type, events, expected_version) do
    Repo.transaction(fn ->
      # 楽観的ロックのチェック
      current_version = get_current_version(aggregate_id)

      if current_version != expected_version do
        Repo.rollback({:error, :concurrency_conflict})
      end

      # イベントの保存
      Enum.reduce(events, current_version, fn event, version ->
        new_version = version + 1

        %Event{}
        |> Event.changeset(%{
          aggregate_id: aggregate_id,
          aggregate_type: aggregate_type,
          event_type: event.__struct__ |> to_string(),
          event_data: Jason.encode!(event),
          event_version: new_version,
          event_metadata: build_metadata()
        })
        |> Repo.insert!()

        new_version
      end)
    end)
  end

  def load_events(aggregate_id) do
    Event
    |> where([e], e.aggregate_id == ^aggregate_id)
    |> order_by([e], asc: e.event_version)
    |> Repo.all()
    |> Enum.map(&deserialize_event/1)
  end

  defp get_current_version(aggregate_id) do
    Event
    |> where([e], e.aggregate_id == ^aggregate_id)
    |> select([e], max(e.event_version))
    |> Repo.one() || 0
  end

  defp deserialize_event(%Event{} = event) do
    module = String.to_existing_atom(event.event_type)
    struct(module, Jason.decode!(event.event_data, keys: :atoms))
  end

  defp build_metadata do
    %{
      timestamp: DateTime.utc_now(),
      correlation_id: get_correlation_id(),
      causation_id: get_causation_id(),
      user_id: get_current_user_id()
    }
  end
end
```

### プロジェクションの実装

```elixir
defmodule QueryService.Infrastructure.Projections.ProductProjection do
  @moduledoc """
  商品の読み取りモデルプロジェクション
  """

  alias QueryService.Infrastructure.ReadModel.Repo
  alias QueryService.Domain.ReadModels.Product

  def handle_event(%ProductCreated{} = event) do
    %Product{}
    |> Product.changeset(%{
      id: event.product_id,
      name: event.name,
      price: event.price,
      category_id: event.category_id,
      created_at: event.created_at,
      updated_at: event.created_at
    })
    |> Repo.insert!()
  end

  def handle_event(%PriceUpdated{} = event) do
    Product
    |> Repo.get!(event.product_id)
    |> Product.changeset(%{
      price: event.new_price,
      updated_at: event.updated_at
    })
    |> Repo.update!()
  end

  def handle_event(%ProductDeleted{} = event) do
    Product
    |> Repo.get!(event.product_id)
    |> Repo.delete!()
  end
end
```

## スナップショット（将来実装）

長いイベント履歴を持つアグリゲートの再構築を高速化するため、スナップショットを実装します。

```elixir
defmodule Shared.Infrastructure.SnapshotStore do
  @snapshot_frequency 100  # 100イベントごとにスナップショット

  def save_snapshot(aggregate_id, aggregate_type, state, version) do
    if rem(version, @snapshot_frequency) == 0 do
      %Snapshot{}
      |> Snapshot.changeset(%{
        aggregate_id: aggregate_id,
        aggregate_type: aggregate_type,
        snapshot_data: serialize_state(state),
        snapshot_version: version,
        created_at: DateTime.utc_now()
      })
      |> Repo.insert!()
    end
  end

  def load_snapshot(aggregate_id) do
    Snapshot
    |> where([s], s.aggregate_id == ^aggregate_id)
    |> order_by([s], desc: s.snapshot_version)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> nil
      snapshot -> deserialize_state(snapshot)
    end
  end
end
```

## イベントバージョニング（将来実装）

システムの進化に伴い、イベントスキーマも変更される必要があります。

```elixir
defmodule Shared.Infrastructure.EventUpgrader do
  def upgrade_event(%{event_type: "ProductCreated", version: 1} = event) do
    # V1からV2への変換
    %{event |
      version: 2,
      data: Map.put(event.data, :sku, generate_sku(event.data))
    }
  end

  def upgrade_event(event), do: event

  defp generate_sku(%{name: name, category_id: category_id}) do
    # SKU生成ロジック
  end
end
```

## ベストプラクティス

### 1. イベントの設計原則

- **ビジネス視点**: 技術的な詳細ではなくビジネスイベントを記録
- **原子性**: 1 つのイベントは 1 つの意味のある変更を表す
- **豊富なコンテキスト**: デバッグと監査に必要な情報を含める

### 2. アグリゲートの境界

```elixir
# 良い例：明確な境界
defmodule Order do
  # 注文に関連するすべてのビジネスロジック
end

defmodule Customer do
  # 顧客に関連するすべてのビジネスロジック
end

# 悪い例：大きすぎるアグリゲート
defmodule ECommerceSystem do
  # すべてのビジネスロジック（避けるべき）
end
```

### 3. イベントの命名規則

```elixir
# 良い例
%OrderPlaced{}
%PaymentProcessed{}
%ShipmentDispatched{}

# 悪い例
%UpdateOrder{}  # 曖昧
%OrderEvent{}   # 一般的すぎる
%SavedToDB{}    # 技術的すぎる
```

### 4. エラーハンドリング

```elixir
defmodule CommandHandler do
  def handle(command) do
    with {:ok, aggregate} <- load_aggregate(command.aggregate_id),
         {:ok, events} <- aggregate.execute(command),
         {:ok, _} <- save_events(events) do
      publish_events(events)
      {:ok, aggregate}
    else
      {:error, :not_found} ->
        {:error, "Aggregate not found"}

      {:error, :concurrency_conflict} ->
        # リトライまたはユーザーに通知
        {:error, "The data has been modified by another process"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## パフォーマンス最適化

### 1. イベントの圧縮

```elixir
defmodule EventCompressor do
  def compress(events) when length(events) > 100 do
    events
    |> Jason.encode!()
    |> :zlib.compress()
    |> Base.encode64()
  end

  def compress(events), do: Jason.encode!(events)
end
```

### 2. パーティショニング

```sql
-- 時系列パーティショニング
CREATE TABLE events_2024_01 PARTITION OF events
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE events_2024_02 PARTITION OF events
  FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
```

### 3. 非同期プロジェクション

```elixir
defmodule AsyncProjectionManager do
  use GenStage

  def handle_events(events, _from, state) do
    # バッチ処理でプロジェクションを更新
    Task.Supervisor.async_stream_nolink(
      ProjectionTaskSupervisor,
      events,
      &update_projection/1,
      max_concurrency: 10
    )
    |> Stream.run()

    {:noreply, events, state}
  end
end
```

## 監視とデバッグ

### イベントストアメトリクス

```elixir
defmodule EventStoreMetrics do
  def track_event_append(aggregate_type, event_count, duration) do
    :telemetry.execute(
      [:event_store, :append],
      %{count: event_count, duration: duration},
      %{aggregate_type: aggregate_type}
    )
  end

  def track_aggregate_load(aggregate_type, event_count, duration) do
    :telemetry.execute(
      [:event_store, :load],
      %{event_count: event_count, duration: duration},
      %{aggregate_type: aggregate_type}
    )
  end
end
```

### イベント監査ログ

```elixir
defmodule EventAuditor do
  require Logger

  def audit_event(event, metadata) do
    Logger.info("Event processed",
      event_type: event.__struct__,
      aggregate_id: event.aggregate_id,
      user_id: metadata.user_id,
      correlation_id: metadata.correlation_id
    )
  end
end
```

## トラブルシューティング

### よくある問題と解決策

#### 1. イベントの順序不整合

**症状**: プロジェクションの状態が期待と異なる

**原因**: イベントが順序通りに処理されていない

**解決策**:

```elixir
def ensure_ordered_processing(events) do
  events
  |> Enum.sort_by(& &1.event_version)
  |> Enum.each(&process_event/1)
end
```

#### 2. イベントストアの肥大化

**症状**: クエリパフォーマンスの低下

**原因**: 古いイベントの蓄積

**解決策**:

- スナップショットの実装
- アーカイブストレージへの移動
- パーティショニングの活用

#### 3. プロジェクションの不整合

**症状**: 読み取りモデルがイベントと同期していない

**原因**: プロジェクション処理の失敗

**解決策**:

```elixir
defmodule ProjectionRebuilder do
  def rebuild_projection(aggregate_id) do
    events = EventStore.load_events(aggregate_id)

    Repo.transaction(fn ->
      # 既存のプロジェクションを削除
      delete_existing_projection(aggregate_id)

      # イベントから再構築
      Enum.each(events, &ProjectionHandler.handle/1)
    end)
  end
end
```

## まとめ

イベントソーシングは強力なパターンですが、適切に実装するには以下が重要です：

1. **明確なイベント設計**: ビジネスドメインを正確に表現
2. **適切なアグリゲート境界**: トランザクション境界の明確化
3. **パフォーマンスの考慮**: スナップショット、パーティショニング
4. **運用の準備**: 監視、デバッグ、リカバリー手順

これらの原則に従うことで、スケーラブルで保守性の高いシステムを構築できます。
