defmodule CommandService.Domain.Sagas.OrderSagaTest do
  use ExUnit.Case, async: true
  
  alias CommandService.Domain.Sagas.OrderSaga
  alias CommandService.Application.Commands.OrderCommands
  
  describe "new/2" do
    test "新しいOrderSagaを作成できる" do
      saga_id = "saga-123"
      initial_data = %{
        order_id: "order-456",
        user_id: "user-789",
        items: [
          %{product_id: "prod-1", quantity: 2},
          %{product_id: "prod-2", quantity: 1}
        ],
        total_amount: 150.0
      }
      
      saga = OrderSaga.new(saga_id, initial_data)
      
      assert saga.saga_id == saga_id
      assert saga.order_id == "order-456"
      assert saga.user_id == "user-789"
      assert saga.state == :started
      assert saga.current_step == :reserve_inventory
      assert length(saga.items) == 2
      assert saga.total_amount == 150.0
      refute saga.inventory_reserved
      refute saga.payment_processed
      refute saga.shipping_arranged
      refute saga.order_confirmed
    end
  end
  
  describe "next_step/1" do
    setup do
      saga = OrderSaga.new("saga-123", %{
        order_id: "order-456",
        user_id: "user-789",
        items: [%{product_id: "prod-1", quantity: 2}],
        total_amount: 100.0
      })
      
      {:ok, saga: saga}
    end
    
    test "在庫確保ステップのコマンドを返す", %{saga: saga} do
      assert {:ok, commands} = OrderSaga.next_step(saga)
      assert length(commands) == 1
      
      [command] = commands
      assert %OrderCommands.ReserveInventory{} = command
      assert command.order_id == "order-456"
      assert length(command.items) == 1
    end
    
    test "支払い処理ステップのコマンドを返す", %{saga: saga} do
      saga = %{saga | current_step: :process_payment, inventory_reserved: true}
      
      assert {:ok, commands} = OrderSaga.next_step(saga)
      assert length(commands) == 1
      
      [command] = commands
      assert %OrderCommands.ProcessPayment{} = command
      assert command.order_id == "order-456"
      assert command.amount == 100.0
    end
    
    test "配送手配ステップのコマンドを返す", %{saga: saga} do
      saga = %{saga | 
        current_step: :arrange_shipping,
        inventory_reserved: true,
        payment_processed: true
      }
      
      assert {:ok, commands} = OrderSaga.next_step(saga)
      assert length(commands) == 1
      
      [command] = commands
      assert %OrderCommands.ArrangeShipping{} = command
      assert command.order_id == "order-456"
    end
    
    test "注文確定ステップのコマンドを返す", %{saga: saga} do
      saga = %{saga | 
        current_step: :confirm_order,
        inventory_reserved: true,
        payment_processed: true,
        shipping_arranged: true
      }
      
      assert {:ok, commands} = OrderSaga.next_step(saga)
      assert length(commands) == 1
      
      [command] = commands
      assert %OrderCommands.ConfirmOrder{} = command
      assert command.order_id == "order-456"
    end
    
    test "完了状態では空のコマンドリストを返す", %{saga: saga} do
      saga = %{saga | state: :completed}
      
      assert {:ok, []} = OrderSaga.next_step(saga)
    end
  end
  
  describe "handle_event/2" do
    setup do
      saga = OrderSaga.new("saga-123", %{
        order_id: "order-456",
        user_id: "user-789",
        items: [%{product_id: "prod-1", quantity: 2}],
        total_amount: 100.0
      })
      
      {:ok, saga: saga}
    end
    
    test "在庫確保成功イベントを処理する", %{saga: saga} do
      event = %{
        event_type: "inventory_reserved",
        aggregate_id: "order-456",
        payload: %{order_id: "order-456", reserved: true}
      }
      
      assert {:ok, commands} = OrderSaga.handle_event(event, saga)
      assert length(commands) == 1
      
      [command] = commands
      assert %OrderCommands.ProcessPayment{} = command
    end
    
    test "在庫確保失敗イベントで補償処理を開始", %{saga: saga} do
      event = %{
        event_type: "inventory_reservation_failed",
        aggregate_id: "order-456",
        payload: %{order_id: "order-456", reason: "out_of_stock"}
      }
      
      assert {:error, _reason} = OrderSaga.handle_event(event, saga)
    end
    
    test "支払い成功イベントを処理する", %{saga: saga} do
      saga = %{saga | current_step: :process_payment, inventory_reserved: true}
      
      event = %{
        event_type: "payment_processed",
        aggregate_id: "order-456",
        payload: %{order_id: "order-456", transaction_id: "tx-123"}
      }
      
      assert {:ok, commands} = OrderSaga.handle_event(event, saga)
      assert length(commands) == 1
      
      [command] = commands
      assert %OrderCommands.ArrangeShipping{} = command
    end
  end
  
  describe "get_compensation_commands/1" do
    test "各ステップに応じた補償コマンドを返す" do
      saga = OrderSaga.new("saga-123", %{
        order_id: "order-456",
        user_id: "user-789",
        items: [%{product_id: "prod-1", quantity: 2}],
        total_amount: 100.0
      })
      
      # 在庫確保済みの場合
      saga = %{saga | inventory_reserved: true}
      commands = OrderSaga.get_compensation_commands(saga)
      assert Enum.any?(commands, fn cmd -> 
        match?(%OrderCommands.ReleaseInventory{}, cmd)
      end)
      
      # 支払い処理済みの場合
      saga = %{saga | payment_processed: true}
      commands = OrderSaga.get_compensation_commands(saga)
      assert Enum.any?(commands, fn cmd -> 
        match?(%OrderCommands.RefundPayment{}, cmd)
      end)
      
      # 配送手配済みの場合
      saga = %{saga | shipping_arranged: true}
      commands = OrderSaga.get_compensation_commands(saga)
      assert Enum.any?(commands, fn cmd -> 
        match?(%OrderCommands.CancelShipping{}, cmd)
      end)
    end
  end
  
  describe "is_completed?/1" do
    test "完了状態を正しく判定する" do
      saga = OrderSaga.new("saga-123", %{})
      
      refute OrderSaga.is_completed?(saga)
      
      completed_saga = %{saga | state: :completed}
      assert OrderSaga.is_completed?(completed_saga)
    end
  end
  
  describe "is_failed?/1" do
    test "失敗状態を正しく判定する" do
      saga = OrderSaga.new("saga-123", %{})
      
      refute OrderSaga.is_failed?(saga)
      
      failed_saga = %{saga | state: :failed}
      assert OrderSaga.is_failed?(failed_saga)
    end
  end
end