defmodule CommandService.Presentation.Grpc.SagaCommandServer do
  @moduledoc """
  サガパターン用のgRPCサーバー実装
  """

  use GRPC.Server, service: Proto.SagaCommand.Service
  require Logger

  alias Shared.Infrastructure.Saga.SagaCoordinator
  alias Shared.Infrastructure.Saga.OrderSaga
  alias Proto.{StartSagaResult, SagaStatusResult, Error}

  @impl true
  def start_order_saga(request, _stream) do
    saga_id = "saga-#{request.orderId}-#{System.unique_integer([:positive])}"
    
    Logger.info("Starting order saga: #{saga_id} for order: #{request.orderId}")
    
    try do
      # サガコンテキストを構築
      saga_context = %{
        saga_id: saga_id,
        order_id: request.orderId,
        customer_id: request.customerId,
        items: Enum.map(request.items, fn item ->
          %{
            product_id: item.productId,
            product_name: item.productName,
            quantity: item.quantity,
            unit_price: item.unitPrice,
            subtotal: item.subtotal
          }
        end),
        total_amount: request.totalAmount,
        shipping_address: %{
          street: request.shippingAddress.street,
          city: request.shippingAddress.city,
          postal_code: request.shippingAddress.postalCode
        }
      }
      
      # SagaCoordinatorを使用してサガを開始
      case SagaCoordinator.start_saga(OrderSaga, saga_context) do
        {:ok, saga_state} ->
          Logger.info("Saga started successfully: #{saga_id}")
          %StartSagaResult{
            sagaId: saga_id,
            status: "started",
            startedAt: %Google.Protobuf.Timestamp{seconds: System.system_time(:second), nanos: 0}
          }
          
        {:error, reason} ->
          Logger.error("Failed to start saga: #{inspect(reason)}")
          %StartSagaResult{
            sagaId: saga_id,
            status: "failed",
            error: %Error{
              message: "Failed to start saga: #{inspect(reason)}"
            },
            startedAt: %Google.Protobuf.Timestamp{seconds: System.system_time(:second), nanos: 0}
          }
      end
    rescue
      error ->
        Logger.error("Exception in start_order_saga: #{inspect(error)}")
        %StartSagaResult{
          sagaId: saga_id,
          status: "failed",
          error: %Error{
            message: "Internal error: #{inspect(error)}"
          },
          startedAt: %Google.Protobuf.Timestamp{seconds: System.system_time(:second), nanos: 0}
        }
    end
  end

  @impl true
  def get_saga_status(request, _stream) do
    # サガリポジトリから状態を取得
    alias Shared.Infrastructure.Saga.SagaRepository
    
    case SagaRepository.get(request.sagaId) do
      {:ok, saga} ->
        %SagaStatusResult{
          sagaId: saga.saga_id,
          state: to_string(saga.state),
          completedSteps: get_completed_step_names(saga),
          currentStep: get_current_step(saga),
          startedAt: datetime_to_timestamp(saga.started_at),
          completedAt: datetime_to_timestamp(saga.completed_at || saga.updated_at),
          error: format_saga_error(saga)
        }
        
      {:error, :not_found} ->
        %SagaStatusResult{
          sagaId: request.sagaId,
          state: "not_found",
          error: %Error{
            message: "Saga not found"
          }
        }
        
      {:error, reason} ->
        %SagaStatusResult{
          sagaId: request.sagaId,
          state: "error",
          error: %Error{
            message: "Failed to retrieve saga status: #{inspect(reason)}"
          }
        }
    end
  end
  
  # Helper functions
  
  defp get_completed_step_names(saga) do
    saga.completed_steps
    |> Enum.map(fn step -> 
      step.step || step[:step] || "unknown_step"
    end)
    |> Enum.reverse()  # 最新のステップが最後に来るように
  end
  
  defp get_current_step(saga) do
    case saga.state do
      :completed -> "completed"
      :failed -> "failed_at_#{saga.failed_step[:step] || "unknown"}"
      :compensating -> "compensating"
      :compensated -> "compensated"
      _ ->
        # 最後に完了したステップの次のステップを推測
        case List.first(saga.completed_steps) do
          nil -> "starting"
          last_step -> "processing_after_#{last_step.step}"
        end
    end
  end
  
  defp datetime_to_timestamp(nil), do: nil
  defp datetime_to_timestamp(%DateTime{} = dt) do
    %Google.Protobuf.Timestamp{
      seconds: DateTime.to_unix(dt),
      nanos: dt.microsecond |> elem(0) |> Kernel.*(1000)
    }
  end
  defp datetime_to_timestamp(_), do: nil
  
  defp format_saga_error(%{state: :failed, failed_step: failed_step}) do
    %Error{
      message: "Failed at step #{failed_step[:step]}: #{failed_step[:reason]}"
    }
  end
  defp format_saga_error(_), do: nil
end