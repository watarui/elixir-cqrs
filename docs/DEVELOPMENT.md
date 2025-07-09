# 開発ガイド

## 開発環境のセットアップ

### エディタ設定

推奨エディタ: Visual Studio Code with ElixirLS extension

```json
// .vscode/settings.json
{
  "elixirLS.suggestSpecs": true,
  "elixirLS.dialyzerEnabled": true,
  "elixirLS.fetchDeps": true,
  "editor.formatOnSave": true,
  "files.trimTrailingWhitespace": true
}
```

### 開発ツール

```bash
# コードフォーマット
mix format

# 静的解析
mix credo --strict

# 型チェック
mix dialyzer

# テスト実行
mix test

# カバレッジレポート
mix coveralls.html
```

## コーディング規約

### モジュール構造

```elixir
defmodule MyApp.Context.Module do
  @moduledoc """
  モジュールの説明
  """

  alias MyApp.OtherModule
  import MyApp.Helpers

  @type t :: %__MODULE__{
    field: String.t()
  }

  defstruct [:field]

  # Public API
  @doc """
  関数の説明
  """
  @spec public_function(arg :: term()) :: {:ok, result :: term()} | {:error, reason :: term()}
  def public_function(arg) do
    # 実装
  end

  # Private functions
  defp private_function do
    # 実装
  end
end
```

### エラーハンドリング

```elixir
# タプルベースのエラーハンドリング
case do_something() do
  {:ok, result} -> handle_success(result)
  {:error, reason} -> handle_error(reason)
end

# with 文を使った複数の操作
with {:ok, user} <- get_user(id),
     {:ok, updated} <- update_user(user, params),
     {:ok, _} <- send_notification(updated) do
  {:ok, updated}
else
  {:error, :not_found} -> {:error, "User not found"}
  {:error, reason} -> {:error, reason}
end
```

## 新機能の追加

### 1. 新しいコマンドの追加

```elixir
# 1. コマンドの定義
# apps/command_service/lib/command_service/application/commands/product_commands.ex
defmodule CommandService.Application.Commands.ProductCommands.DiscountProduct do
  use Shared.Domain.BaseCommand

  embedded_schema do
    field :product_id, :binary_id
    field :discount_percentage, :integer
  end
end

# 2. アグリゲートにロジックを追加
# apps/command_service/lib/command_service/domain/aggregates/product_aggregate.ex
def execute(aggregate, %DiscountProduct{} = command) do
  # ビジネスロジックの実装
  event = ProductDiscounted.new(%{
    id: aggregate.id,
    discount_percentage: command.discount_percentage,
    discounted_at: DateTime.utc_now()
  })
  
  {:ok, apply_event(aggregate, event), [event]}
end

# 3. ハンドラーに処理を追加
# apps/command_service/lib/command_service/application/handlers/product_command_handler.ex
def handle(%DiscountProduct{} = command) do
  # 実装
end

# 4. CommandBus にルーティングを追加
# apps/command_service/lib/command_service/infrastructure/command_bus.ex
defp route_command(%DiscountProduct{} = cmd), do: ProductCommandHandler.handle(cmd)
```

### 2. 新しいクエリの追加

```elixir
# 1. クエリの定義
# apps/query_service/lib/query_service/application/queries/product_queries.ex
defmodule QueryService.Application.Queries.GetDiscountedProducts do
  defstruct [:min_discount]
end

# 2. ハンドラーの実装
# apps/query_service/lib/query_service/application/handlers/product_query_handler.ex
def handle(%GetDiscountedProducts{min_discount: min_discount}) do
  ProductRepository.get_discounted_products(min_discount)
end

# 3. リポジトリメソッドの追加
# apps/query_service/lib/query_service/infrastructure/repositories/product_repository.ex
def get_discounted_products(min_discount) do
  query = from p in ProductSchema,
    where: p.discount_percentage >= ^min_discount,
    order_by: [desc: p.discount_percentage]
  
  products = Repo.all(query)
  {:ok, Enum.map(products, &to_domain_model/1)}
end
```

### 3. GraphQL の拡張

```elixir
# 1. スキーマに型を追加
# apps/client_service/lib/client_service/graphql/schema/product_types.ex
object :product_mutations do
  field :discount_product, :product do
    arg :product_id, non_null(:id)
    arg :discount_percentage, non_null(:integer)
    
    resolve &ProductResolver.discount_product/3
  end
end

# 2. リゾルバーの実装
# apps/client_service/lib/client_service/graphql/resolvers/product_resolver.ex
def discount_product(_parent, %{product_id: id, discount_percentage: discount}, _resolution) do
  # gRPC 呼び出しの実装
end
```

## テスト

### ユニットテスト

```elixir
# test/my_module_test.exs
defmodule MyModuleTest do
  use ExUnit.Case, async: true

  describe "my_function/1" do
    test "returns expected result" do
      assert {:ok, result} = MyModule.my_function("input")
      assert result == "expected"
    end

    test "handles error case" do
      assert {:error, reason} = MyModule.my_function(nil)
      assert reason == :invalid_input
    end
  end
end
```

### 統合テスト

```elixir
# test/integration/command_flow_test.exs
defmodule CommandFlowTest do
  use ExUnit.Case
  
  setup do
    # データベースのクリーンアップ
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    
    # テストデータの準備
    {:ok, category} = create_test_category()
    
    {:ok, category: category}
  end

  test "complete command flow", %{category: category} do
    # コマンドの実行
    command = %CreateProduct{
      name: "Test Product",
      category_id: category.id
    }
    
    assert {:ok, aggregate} = CommandBus.dispatch(command)
    
    # イベントの確認
    assert {:ok, events} = EventStore.get_events(aggregate.id)
    assert length(events) == 1
    
    # Read Model の確認
    Process.sleep(100) # プロジェクションの処理待ち
    assert {:ok, product} = ProductRepository.get(aggregate.id)
    assert product.name == "Test Product"
  end
end
```

## デバッグ

### IEx での調査

```elixir
# プロセスの状態を確認
:sys.get_state(CommandService.Infrastructure.CommandBus)

# イベントストアの内容を確認
EventStore.get_events("aggregate-id")

# Read Model のデータを確認
QueryService.Infrastructure.Repositories.ProductRepository.get_all()

# メトリクスの確認
:telemetry.execute([:my_app, :metric], %{count: 1}, %{})
```

### ログ設定

```elixir
# config/dev.exs
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id]

# 特定モジュールのログレベル変更
config :logger,
  compile_time_purge_matching: [
    [application: :grpc, level_lower_than: :info]
  ]
```

## パフォーマンスチューニング

### データベース

```elixir
# インデックスの追加
create index(:products, [:category_id])
create index(:products, [:created_at])

# 複合インデックス
create index(:products, [:category_id, :active])
```

### 並行処理

```elixir
# Task による並列処理
tasks = Enum.map(items, fn item ->
  Task.async(fn -> process_item(item) end)
end)

results = Task.await_many(tasks, 5000)

# GenStage による処理
defmodule Producer do
  use GenStage
  
  def handle_demand(demand, state) do
    events = fetch_events(demand)
    {:noreply, events, state}
  end
end
```

## リリース

### ビルド

```bash
# リリースビルド
MIX_ENV=prod mix release

# Docker イメージ
docker build -t myapp:latest .
```

### 環境変数

```bash
# 本番環境設定
DATABASE_URL=postgres://user:pass@host/db
SECRET_KEY_BASE=your-secret-key
GRPC_PORT=50051
```