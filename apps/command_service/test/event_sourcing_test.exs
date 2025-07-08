defmodule CommandService.EventSourcingTest do
  @moduledoc """
  イベントソーシングのテスト
  """

  use ExUnit.Case

  alias CommandService.Application.CommandBus
  alias CommandService.Application.Commands.ProductCommands.CreateProduct
  alias Shared.Infrastructure.EventStore

  test "商品作成コマンドがイベントを生成し保存する" do
    # コマンドを作成
    command =
      CreateProduct.new(%{
        id: Ecto.UUID.generate(),
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
    assert {:ok, events} = CommandBus.execute(command)

    # イベントが生成されたことを確認
    assert length(events) > 0
    [_first_event | _] = events

    # イベントストアからイベントを読み取る
    assert {:ok, stored_events} = EventStore.read_aggregate_events(command.id)
    assert length(stored_events) > 0

    # 最初のイベントがProductCreatedであることを確認
    [stored_first_event | _] = stored_events
    assert stored_first_event.__struct__ == Shared.Domain.Events.ProductEvents.ProductCreated
    assert stored_first_event.aggregate_id == command.id
    assert stored_first_event.name == "Test Product"
  end
end
