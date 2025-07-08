defmodule CommandService.EventSourcingTest do
  @moduledoc """
  イベントソーシングのテスト
  """

  use ExUnit.Case

  alias CommandService.Application.CommandBus
  alias CommandService.Application.Commands.ProductCommands.CreateProductCommand
  alias Shared.Infrastructure.EventStore

  test "商品作成コマンドがイベントを生成し保存する" do
    # コマンドを作成
    command =
      CreateProductCommand.new(%{
        name: "Test Product",
        price: "1999.99",
        category_id: "test-category-id",
        metadata: %{
          user_id: "test-user",
          request_id: Ecto.UUID.generate(),
          timestamp: DateTime.utc_now()
        }
      })

    # コマンドを実行
    assert {:ok, result} = CommandBus.execute(command)

    # イベントが生成されたことを確認
    assert is_binary(result.aggregate_id)
    assert length(result.events) > 0

    # イベントストアからイベントを読み取る
    assert {:ok, events} = EventStore.read_aggregate_events(result.aggregate_id)
    assert length(events) > 0

    # 最初のイベントがProductCreatedであることを確認
    [first_event | _] = events
    assert first_event.__struct__ == Shared.Domain.Events.ProductEvents.ProductCreated
    assert first_event.aggregate_id == result.aggregate_id
    assert first_event.name == "Test Product"
  end
end
