defmodule Shared.Domain.Saga.SagaEvents do
  @moduledoc """
  サガ関連のイベント定義
  """
  
  alias Shared.Domain.Events.BaseEvent
  
  defmodule SagaStarted do
    @moduledoc """
    サガが開始されたイベント
    """
    use BaseEvent
    
    defstruct [
      :event_id,
      :aggregate_id,
      :event_type,
      :event_version,
      :occurred_at,
      :payload,
      :metadata,
      :saga_type,
      :initial_data
    ]
    
    def new(saga_id, saga_type, initial_data, metadata \\ %{}) do
      %__MODULE__{
        event_id: UUID.uuid4(),
        aggregate_id: saga_id,
        event_type: "saga_started",
        event_version: 1,
        occurred_at: DateTime.utc_now(),
        saga_type: saga_type,
        initial_data: initial_data,
        payload: %{
          saga_type: saga_type,
          initial_data: initial_data
        },
        metadata: metadata
      }
    end
  end
  
  defmodule SagaStepCompleted do
    @moduledoc """
    サガのステップが完了したイベント
    """
    use BaseEvent
    
    defstruct [
      :event_id,
      :aggregate_id,
      :event_type,
      :event_version,
      :occurred_at,
      :payload,
      :metadata,
      :step_name,
      :result
    ]
    
    def new(saga_id, step_name, result, metadata \\ %{}) do
      %__MODULE__{
        event_id: UUID.uuid4(),
        aggregate_id: saga_id,
        event_type: "saga_step_completed",
        event_version: 1,
        occurred_at: DateTime.utc_now(),
        step_name: step_name,
        result: result,
        payload: %{
          step_name: step_name,
          result: result
        },
        metadata: metadata
      }
    end
  end
  
  defmodule SagaFailed do
    @moduledoc """
    サガが失敗したイベント
    """
    use BaseEvent
    
    defstruct [
      :event_id,
      :aggregate_id,
      :event_type,
      :event_version,
      :occurred_at,
      :payload,
      :metadata,
      :failed_step,
      :reason
    ]
    
    def new(saga_id, failed_step, reason, metadata \\ %{}) do
      %__MODULE__{
        event_id: UUID.uuid4(),
        aggregate_id: saga_id,
        event_type: "saga_failed",
        event_version: 1,
        occurred_at: DateTime.utc_now(),
        failed_step: failed_step,
        reason: reason,
        payload: %{
          failed_step: failed_step,
          reason: reason
        },
        metadata: metadata
      }
    end
  end
  
  defmodule SagaCompensationStarted do
    @moduledoc """
    サガの補償処理が開始されたイベント
    """
    use BaseEvent
    
    defstruct [
      :event_id,
      :aggregate_id,
      :event_type,
      :event_version,
      :occurred_at,
      :payload,
      :metadata
    ]
    
    def new(saga_id, metadata \\ %{}) do
      %__MODULE__{
        event_id: UUID.uuid4(),
        aggregate_id: saga_id,
        event_type: "saga_compensation_started",
        event_version: 1,
        occurred_at: DateTime.utc_now(),
        payload: %{},
        metadata: metadata
      }
    end
  end
  
  defmodule SagaCompensated do
    @moduledoc """
    サガの補償処理が完了したイベント
    """
    use BaseEvent
    
    defstruct [
      :event_id,
      :aggregate_id,
      :event_type,
      :event_version,
      :occurred_at,
      :payload,
      :metadata
    ]
    
    def new(saga_id, metadata \\ %{}) do
      %__MODULE__{
        event_id: UUID.uuid4(),
        aggregate_id: saga_id,
        event_type: "saga_compensated",
        event_version: 1,
        occurred_at: DateTime.utc_now(),
        payload: %{},
        metadata: metadata
      }
    end
  end
  
  defmodule SagaCompleted do
    @moduledoc """
    サガが正常に完了したイベント
    """
    use BaseEvent
    
    defstruct [
      :event_id,
      :aggregate_id,
      :event_type,
      :event_version,
      :occurred_at,
      :payload,
      :metadata,
      :final_result
    ]
    
    def new(saga_id, final_result, metadata \\ %{}) do
      %__MODULE__{
        event_id: UUID.uuid4(),
        aggregate_id: saga_id,
        event_type: "saga_completed",
        event_version: 1,
        occurred_at: DateTime.utc_now(),
        final_result: final_result,
        payload: %{
          final_result: final_result
        },
        metadata: metadata
      }
    end
  end
end