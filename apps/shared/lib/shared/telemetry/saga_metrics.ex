defmodule Shared.Telemetry.SagaMetrics do
  @moduledoc """
  サガ関連のメトリクス定義とヘルパー関数
  """
  
  import Telemetry.Metrics
  
  @doc """
  サガ関連のメトリクス定義
  """
  def metrics do
    [
      # サガの開始数
      counter("saga.started.count",
        tags: [:saga_type]
      ),
      
      # サガの完了数
      counter("saga.completed.count",
        tags: [:saga_type]
      ),
      
      # サガの失敗数
      counter("saga.failed.count",
        tags: [:saga_type, :failed_step]
      ),
      
      # サガの補償実行数
      counter("saga.compensation.count",
        tags: [:saga_type]
      ),
      
      # サガの実行時間
      summary("saga.duration",
        unit: {:native, :millisecond},
        tags: [:saga_type, :status]
      ),
      
      # ステップの実行時間
      summary("saga.step.duration",
        unit: {:native, :millisecond},
        tags: [:saga_type, :step_name]
      ),
      
      # アクティブなサガ数
      last_value("saga.active.count",
        tags: [:saga_type]
      ),
      
      # タイムアウトしたサガ数
      counter("saga.timeout.count",
        tags: [:saga_type]
      )
    ]
  end
  
  @doc """
  サガ開始を記録
  """
  def record_saga_started(saga_type) do
    :telemetry.execute(
      [:saga, :started],
      %{count: 1},
      %{saga_type: saga_type}
    )
  end
  
  @doc """
  サガ完了を記録
  """
  def record_saga_completed(saga_type, duration_ms) do
    :telemetry.execute(
      [:saga, :completed],
      %{count: 1, duration: duration_ms},
      %{saga_type: saga_type, status: :completed}
    )
  end
  
  @doc """
  サガ失敗を記録
  """
  def record_saga_failed(saga_type, failed_step, duration_ms) do
    :telemetry.execute(
      [:saga, :failed],
      %{count: 1, duration: duration_ms},
      %{saga_type: saga_type, failed_step: failed_step, status: :failed}
    )
  end
  
  @doc """
  サガ補償開始を記録
  """
  def record_saga_compensation_started(saga_type) do
    :telemetry.execute(
      [:saga, :compensation],
      %{count: 1},
      %{saga_type: saga_type}
    )
  end
  
  @doc """
  ステップ実行を記録
  """
  def record_step_execution(saga_type, step_name, duration_ms) do
    :telemetry.execute(
      [:saga, :step],
      %{duration: duration_ms},
      %{saga_type: saga_type, step_name: step_name}
    )
  end
  
  @doc """
  アクティブなサガ数を更新
  """
  def update_active_saga_count(counts_by_type) do
    Enum.each(counts_by_type, fn {saga_type, count} ->
      :telemetry.execute(
        [:saga, :active],
        %{count: count},
        %{saga_type: saga_type}
      )
    end)
  end
  
  @doc """
  サガタイムアウトを記録
  """
  def record_saga_timeout(saga_type) do
    :telemetry.execute(
      [:saga, :timeout],
      %{count: 1},
      %{saga_type: saga_type}
    )
  end
end