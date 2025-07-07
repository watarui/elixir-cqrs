defmodule CommandService.Presentation.Grpc.SagaCommandServer do
  @moduledoc """
  サガパターン用のgRPCサーバー実装
  """

  use GRPC.Server, service: Proto.SagaCommand.Service

  alias CommandService.Application.Handlers.OrderCommandHandler
  alias CommandService.Domain.Commands.{
    ReserveInventory,
    ProcessPayment,
    ArrangeShipping,
    ConfirmOrder
  }
  alias CommandService.Infrastructure.CommandBus
  alias Proto.{StartSagaResult, SagaStatusResult, Error}

  @impl true
  def start_order_saga(request, _stream) do
    saga_id = "saga-#{request.orderId}-#{System.unique_integer([:positive])}"
    
    try do
      # 注文サガの各ステップを順番に実行
      # Step 1: 在庫予約
      inventory_commands = Enum.map(request.items, fn item ->
        %ReserveInventory{
          order_id: request.orderId,
          product_id: item.productId,
          quantity: item.quantity
        }
      end)
      
      Enum.each(inventory_commands, fn cmd ->
        case CommandBus.dispatch(cmd) do
          {:ok, _} -> :ok
          {:error, reason} -> throw({:inventory_failed, reason})
        end
      end)
      
      # Step 2: 支払い処理
      payment_command = %ProcessPayment{
        order_id: request.orderId,
        customer_id: request.customerId,
        amount: request.totalAmount
      }
      
      case CommandBus.dispatch(payment_command) do
        {:ok, _} -> :ok
        {:error, reason} -> throw({:payment_failed, reason})
      end
      
      # Step 3: 配送手配
      shipping_command = %ArrangeShipping{
        order_id: request.orderId,
        shipping_address: %{
          street: request.shippingAddress.street,
          city: request.shippingAddress.city,
          postal_code: request.shippingAddress.postalCode
        }
      }
      
      case CommandBus.dispatch(shipping_command) do
        {:ok, _} -> :ok
        {:error, reason} -> throw({:shipping_failed, reason})
      end
      
      # Step 4: 注文確定
      confirm_command = %ConfirmOrder{
        order_id: request.orderId
      }
      
      case CommandBus.dispatch(confirm_command) do
        {:ok, _} -> :ok
        {:error, reason} -> throw({:confirmation_failed, reason})
      end
      
      # 成功レスポンス
      %StartSagaResult{
        sagaId: saga_id,
        status: "completed",
        startedAt: Google.Protobuf.Timestamp.new(seconds: System.system_time(:second))
      }
    catch
      {step, reason} ->
        # エラーレスポンス
        %StartSagaResult{
          sagaId: saga_id,
          status: "failed",
          error: %Error{
            message: "Saga failed at #{step}: #{inspect(reason)}"
          },
          startedAt: Google.Protobuf.Timestamp.new(seconds: System.system_time(:second))
        }
    end
  end

  @impl true
  def get_saga_status(request, _stream) do
    # 実際の実装では、サガの状態を永続化層から取得する
    # 今回は簡易実装として、常に完了状態を返す
    %SagaStatusResult{
      sagaId: request.sagaId,
      state: "completed",
      completedSteps: ["inventory_reserved", "payment_processed", "shipping_arranged", "order_confirmed"],
      currentStep: "completed",
      startedAt: Google.Protobuf.Timestamp.new(seconds: System.system_time(:second) - 60),
      completedAt: Google.Protobuf.Timestamp.new(seconds: System.system_time(:second))
    }
  end
end