defmodule Shared.Domain.Saga.SagaEvents do
  @moduledoc """
  サガ関連のイベント定義
  """

  alias Shared.Domain.Events.BaseEvent

  defmodule SagaStarted do
    @moduledoc """
    サガ開始イベント
    """
    use BaseEvent

    @enforce_keys [:saga_id, :saga_type, :metadata, :occurred_at]
    defstruct [:saga_id, :saga_type, :metadata, :occurred_at, :event_id, :version]

    @impl true
    def new(attrs) do
      struct!(__MODULE__, Map.put(attrs, :event_id, UUID.uuid4()))
    end

    @impl true
    def event_type, do: "saga.started"
  end

  defmodule SagaStepCompleted do
    @moduledoc """
    サガステップ完了イベント
    """
    use BaseEvent

    @enforce_keys [:saga_id, :saga_type, :current_step, :occurred_at]
    defstruct [:saga_id, :saga_type, :current_step, :metadata, :occurred_at, :event_id, :version]

    @impl true
    def new(attrs) do
      struct!(__MODULE__, Map.put(attrs, :event_id, UUID.uuid4()))
    end

    @impl true
    def event_type, do: "saga.step_completed"
  end

  defmodule SagaFailed do
    @moduledoc """
    サガ失敗イベント
    """
    use BaseEvent

    @enforce_keys [:saga_id, :saga_type, :failed_step, :reason, :occurred_at]
    defstruct [
      :saga_id,
      :saga_type,
      :failed_step,
      :reason,
      :metadata,
      :occurred_at,
      :event_id,
      :version
    ]

    @impl true
    def new(attrs) do
      struct!(__MODULE__, Map.put(attrs, :event_id, UUID.uuid4()))
    end

    @impl true
    def event_type, do: "saga.failed"
  end

  defmodule SagaCompensationStarted do
    @moduledoc """
    サガ補償開始イベント
    """
    use BaseEvent

    @enforce_keys [:saga_id, :saga_type, :reason, :occurred_at]
    defstruct [:saga_id, :saga_type, :reason, :metadata, :occurred_at, :event_id, :version]

    @impl true
    def new(attrs) do
      struct!(__MODULE__, Map.put(attrs, :event_id, UUID.uuid4()))
    end

    @impl true
    def event_type, do: "saga.compensation_started"
  end

  defmodule SagaCompensated do
    @moduledoc """
    サガ補償完了イベント
    """
    use BaseEvent

    @enforce_keys [:saga_id, :saga_type, :occurred_at]
    defstruct [:saga_id, :saga_type, :metadata, :occurred_at, :event_id, :version]

    @impl true
    def new(attrs) do
      struct!(__MODULE__, Map.put(attrs, :event_id, UUID.uuid4()))
    end

    @impl true
    def event_type, do: "saga.compensated"
  end

  defmodule SagaCompleted do
    @moduledoc """
    サガ完了イベント
    """
    use BaseEvent

    @enforce_keys [:saga_id, :saga_type, :occurred_at]
    defstruct [:saga_id, :saga_type, :metadata, :occurred_at, :event_id, :version]

    @impl true
    def new(attrs) do
      struct!(__MODULE__, Map.put(attrs, :event_id, UUID.uuid4()))
    end

    @impl true
    def event_type, do: "saga.completed"
  end

  defmodule SagaUpdated do
    @moduledoc """
    サガ更新イベント
    """
    use BaseEvent

    @enforce_keys [:saga_id, :saga_type, :state, :occurred_at]
    defstruct [
      :saga_id,
      :saga_type,
      :state,
      :current_step,
      :metadata,
      :occurred_at,
      :event_id,
      :version
    ]

    @impl true
    def new(attrs) do
      struct!(__MODULE__, Map.put(attrs, :event_id, UUID.uuid4()))
    end

    @impl true
    def event_type, do: "saga.updated"
  end
end
