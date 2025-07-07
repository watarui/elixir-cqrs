defmodule Shared.Infrastructure.Saga.OrderSaga do
  @moduledoc """
  注文処理のSaga実装
  """

  use Shared.Domain.Saga.SagaDefinition
  require Logger

  @impl true
  def name, do: "OrderSaga"
  
  @doc """
  イベントを処理してコマンドを返す
  """
  def handle_event(%{event_type: "saga_started"}, saga) do
    # 最初のステップ（在庫予約）を実行
    case steps() |> List.first() do
      nil -> 
        {:error, :no_steps_defined}
      %{handler: handler} ->
        case handler.(saga.context) do
          {:ok, result} ->
            commands = build_reserve_inventory_commands(saga.context)
            {:ok, commands}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end
  
  def handle_event(%{event_type: "inventory_reserved"}, saga) do
    # 次のステップ（支払い処理）を実行
    {:ok, build_payment_commands(saga.context)}
  end
  
  def handle_event(%{event_type: "payment_processed"}, saga) do
    # 次のステップ（配送手配）を実行
    {:ok, build_shipping_commands(saga.context)}
  end
  
  def handle_event(%{event_type: "shipping_arranged"}, saga) do
    # 最後のステップ（注文確定）を実行
    {:ok, build_order_confirmation_commands(saga.context)}
  end
  
  def handle_event(%{event_type: "order_confirmed"}, saga) do
    # すべて完了
    {:ok, []}
  end
  
  def handle_event(event, _saga) do
    {:error, "Unknown event type: #{event.event_type}"}
  end
  
  # Helper functions for building commands
  defp build_reserve_inventory_commands(context) do
    Enum.map(context.items, fn item ->
      %{
        type: "reserve_inventory",
        payload: %{
          order_id: context.order_id,
          product_id: item.product_id,
          quantity: item.quantity
        }
      }
    end)
  end
  
  defp build_payment_commands(context) do
    [%{
      type: "process_payment",
      payload: %{
        order_id: context.order_id,
        customer_id: context.customer_id,
        amount: context.total_amount
      }
    }]
  end
  
  defp build_shipping_commands(context) do
    [%{
      type: "arrange_shipping",
      payload: %{
        order_id: context.order_id,
        shipping_address: context.shipping_address
      }
    }]
  end
  
  defp build_order_confirmation_commands(context) do
    [%{
      type: "confirm_order",
      payload: %{
        order_id: context.order_id
      }
    }]
  end
  
  @doc """
  新しいサガを開始する
  """
  def start(saga_id, initial_data) do
    %{
      saga_id: saga_id,
      saga_type: "OrderSaga",
      state: :started,
      context: initial_data,
      completed_steps: [],
      failed_step: nil,
      failure_reason: nil,
      processed_events: [],
      started_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
  
  # Helper function
  defp generate_id do
    "#{System.unique_integer([:positive])}-#{System.system_time(:millisecond)}"
  end

  @impl true
  def steps do
    [
      # Step 1: 在庫予約
      %{
        step: :reserve_inventory,
        handler: &reserve_inventory/1,
        compensation: &cancel_inventory/1
      },
      
      # Step 2: 支払い処理
      %{
        step: :process_payment,
        handler: &process_payment/1,
        compensation: &refund_payment/1
      },
      
      # Step 3: 配送手配
      %{
        step: :arrange_shipping,
        handler: &arrange_shipping/1,
        compensation: &cancel_shipping/1
      },
      
      # Step 4: 注文確定
      %{
        step: :confirm_order,
        handler: &confirm_order/1,
        compensation: nil  # 注文確定は補償不要
      }
    ]
  end

  # Step Handlers
  
  defp reserve_inventory(context) do
    commands = Enum.map(context.items, fn item ->
      %{
        type: "reserve_inventory",
        payload: %{
          order_id: context.order_id,
          product_id: item.product_id,
          quantity: item.quantity
        }
      }
    end)
    
    # 複数の在庫予約コマンドを並列実行
    case dispatch_parallel(commands) do
      {:ok, results} ->
        {:ok, %{reserved_items: context.items}}
      {:error, errors} ->
        Logger.error("Failed to reserve inventory: #{inspect(errors)}")
        {:error, :inventory_reservation_failed}
    end
  end
  
  defp process_payment(context) do
    command = %{
      type: "process_payment",
      payload: %{
        order_id: context.order_id,
        customer_id: context.customer_id,
        amount: context.total_amount
      }
    }
    
    case dispatch(command) do
      {:ok, result} -> {:ok, %{payment_id: result[:payment_id] || generate_id()}}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp arrange_shipping(context) do
    command = %{
      type: "arrange_shipping",
      payload: %{
        order_id: context.order_id,
        shipping_address: context.shipping_address
      }
    }
    
    case dispatch(command) do
      {:ok, result} -> {:ok, %{shipping_id: result[:shipping_id] || generate_id()}}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp confirm_order(context) do
    command = %{
      type: "confirm_order",
      payload: %{
        order_id: context.order_id
      }
    }
    
    case dispatch(command) do
      {:ok, result} -> {:ok, %{confirmed_at: DateTime.utc_now()}}
      {:error, reason} -> {:error, reason}
    end
  end

  # SAGAの状態管理関数
  def is_completed?(saga) do
    saga.state == :completed
  end
  
  def is_failed?(saga) do
    saga.state == :failed
  end
  
  def is_timed_out?(saga, timeout) do
    elapsed = DateTime.diff(DateTime.utc_now(), saga.started_at, :millisecond)
    elapsed > timeout
  end
  
  def mark_event_processed(saga, event) do
    processed_events = Map.get(saga, :processed_events, [])
    %{saga | processed_events: [{event.event_id, DateTime.utc_now()} | processed_events]}
  end
  
  def mark_step_completed(saga, step_name, result) do
    completed_steps = Map.get(saga, :completed_steps, [])
    %{saga | 
      completed_steps: [step_name | completed_steps],
      updated_at: DateTime.utc_now()
    }
  end
  
  def mark_failed(saga, failed_step, reason) do
    %{saga | 
      state: :failed,
      failed_step: failed_step,
      failure_reason: reason,
      updated_at: DateTime.utc_now()
    }
  end
  
  def start_compensation(saga) do
    %{saga | 
      state: :compensating,
      updated_at: DateTime.utc_now()
    }
  end
  
  def get_compensation_commands(saga) do
    # 完了したステップの逆順で補償コマンドを生成
    saga.completed_steps
    |> Enum.reverse()
    |> Enum.flat_map(fn step ->
      case step do
        :reserve_inventory ->
          Enum.map(saga.context.items, fn item ->
            %{
              type: "cancel_inventory",
              payload: %{
                order_id: saga.context.order_id,
                product_id: item.product_id,
                quantity: item.quantity
              }
            }
          end)
          
        :process_payment ->
          [%{
            type: "refund_payment",
            payload: %{
              order_id: saga.context.order_id,
              payment_id: Map.get(saga.context, :payment_id, "unknown"),
              amount: saga.context.total_amount
            }
          }]
          
        :arrange_shipping ->
          [%{
            type: "cancel_shipping",
            payload: %{
              order_id: saga.context.order_id,
              shipping_id: Map.get(saga.context, :shipping_id, "unknown")
            }
          }]
          
        _ ->
          []
      end
    end)
  end
  
  def new(saga_id, initial_data) do
    start(saga_id, initial_data)
  end
  
  def next_step(saga) do
    # 次に実行すべきステップを返す
    steps_defined = steps() |> Enum.map(& &1.step)
    completed = MapSet.new(saga.completed_steps)
    
    next = Enum.find(steps_defined, fn step ->
      not MapSet.member?(completed, step)
    end)
    
    if next do
      {:ok, [build_command_for_step(next, saga.context)]}
    else
      {:ok, []}  # すべて完了
    end
  end
  
  defp build_command_for_step(:reserve_inventory, context) do
    build_reserve_inventory_commands(context) |> List.first()
  end
  
  defp build_command_for_step(:process_payment, context) do
    build_payment_commands(context) |> List.first()
  end
  
  defp build_command_for_step(:arrange_shipping, context) do
    build_shipping_commands(context) |> List.first()
  end
  
  defp build_command_for_step(:confirm_order, context) do
    build_order_confirmation_commands(context) |> List.first()
  end
  
  # Compensation Handlers
  
  defp cancel_inventory(context) do
    commands = Enum.map(context.items, fn item ->
      %{
        type: "cancel_inventory",
        payload: %{
          order_id: context.order_id,
          product_id: item.product_id,
          quantity: item.quantity
        }
      }
    end)
    
    dispatch_compensation(commands)
    {:ok, %{inventory_cancelled: true}}
  end
  
  defp refund_payment(context) do
    command = %{
      type: "refund_payment",
      payload: %{
        order_id: context.order_id,
        payment_id: context[:payment_id] || "unknown",
        amount: context.total_amount
      }
    }
    
    dispatch_compensation(command)
    {:ok, %{payment_refunded: true}}
  end
  
  defp cancel_shipping(context) do
    command = %{
      type: "cancel_shipping",
      payload: %{
        order_id: context.order_id,
        shipping_id: context[:shipping_id] || "unknown"
      }
    }
    
    dispatch_compensation(command)
    {:ok, %{shipping_cancelled: true}}
  end
end