defmodule Shared.Infrastructure.Saga.SagaMonitor do
  @moduledoc """
  Sagaの実行状況を監視し、メトリクスを収集するモジュール

  各ステップの実行時間、成功率、タイムアウト率などを追跡し、
  問題の早期発見とパフォーマンス分析を可能にする。
  """

  use GenServer

  require Logger

  @telemetry_events [
    [:saga, :started],
    [:saga, :completed],
    [:saga, :failed],
    [:saga, :step_completed],
    [:saga, :step_compensated],
    [:saga, :step_timeout],
    [:saga, :timeout, :started],
    [:saga, :timeout, :triggered]
  ]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  現在のメトリクスを取得
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  特定のSagaタイプのメトリクスを取得
  """
  def get_saga_metrics(saga_type) do
    GenServer.call(__MODULE__, {:get_saga_metrics, saga_type})
  end

  @doc """
  特定のステップのメトリクスを取得
  """
  def get_step_metrics(saga_type, step_name) do
    GenServer.call(__MODULE__, {:get_step_metrics, saga_type, step_name})
  end

  @doc """
  メトリクスをリセット
  """
  def reset_metrics do
    GenServer.cast(__MODULE__, :reset_metrics)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Telemetryイベントにアタッチ
    attach_telemetry_handlers()

    state = %{
      # saga_type -> metrics
      saga_metrics: %{},
      # {saga_type, step_name} -> metrics
      step_metrics: %{},
      # 全体的な統計
      global_metrics: %{
        total_started: 0,
        total_completed: 0,
        total_failed: 0,
        total_compensated: 0,
        total_timeouts: 0,
        active_sagas: 0
      }
    }

    # 定期的なレポート
    schedule_report()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      global: state.global_metrics,
      by_saga: summarize_saga_metrics(state.saga_metrics),
      by_step: summarize_step_metrics(state.step_metrics)
    }

    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call({:get_saga_metrics, saga_type}, _from, state) do
    metrics = Map.get(state.saga_metrics, saga_type, default_saga_metrics())
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_call({:get_step_metrics, saga_type, step_name}, _from, state) do
    metrics = Map.get(state.step_metrics, {saga_type, step_name}, default_step_metrics())
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_cast(:reset_metrics, _state) do
    {:noreply, init_state()}
  end

  @impl true
  def handle_info(:generate_report, state) do
    generate_and_log_report(state)
    schedule_report()
    {:noreply, state}
  end

  @impl true
  def handle_info({:telemetry_event, event_name, measurements, metadata}, state) do
    new_state = handle_telemetry_event(event_name, measurements, metadata, state)
    {:noreply, new_state}
  end

  # Private functions

  defp attach_telemetry_handlers do
    Enum.each(@telemetry_events, fn event ->
      :telemetry.attach(
        {__MODULE__, event},
        event,
        &handle_telemetry/4,
        nil
      )
    end)
  end

  defp handle_telemetry(event_name, measurements, metadata, _config) do
    send(self(), {:telemetry_event, event_name, measurements, metadata})
  end

  defp handle_telemetry_event([:saga, :started], _measurements, metadata, state) do
    saga_type = metadata.saga_type

    # グローバルメトリクスを更新
    global_metrics =
      state.global_metrics
      |> Map.update(:total_started, 1, &(&1 + 1))
      |> Map.update(:active_sagas, 1, &(&1 + 1))

    # Sagaタイプ別メトリクスを更新
    saga_metrics =
      Map.update(state.saga_metrics, saga_type, default_saga_metrics(), fn metrics ->
        metrics
        |> Map.update(:total_started, 1, &(&1 + 1))
        |> Map.update(:active_count, 1, &(&1 + 1))
        |> Map.put(:last_started_at, DateTime.utc_now())
      end)

    %{state | global_metrics: global_metrics, saga_metrics: saga_metrics}
  end

  defp handle_telemetry_event([:saga, :completed], measurements, metadata, state) do
    saga_type = metadata.saga_type
    duration = measurements[:duration] || 0

    # グローバルメトリクスを更新
    global_metrics =
      state.global_metrics
      |> Map.update(:total_completed, 1, &(&1 + 1))
      |> Map.update(:active_sagas, 0, &max(&1 - 1, 0))

    # Sagaタイプ別メトリクスを更新
    saga_metrics =
      Map.update(state.saga_metrics, saga_type, default_saga_metrics(), fn metrics ->
        metrics
        |> Map.update(:total_completed, 1, &(&1 + 1))
        |> Map.update(:active_count, 0, &max(&1 - 1, 0))
        |> update_duration_stats(duration)
        |> Map.put(:last_completed_at, DateTime.utc_now())
      end)

    %{state | global_metrics: global_metrics, saga_metrics: saga_metrics}
  end

  defp handle_telemetry_event([:saga, :failed], _measurements, metadata, state) do
    saga_type = metadata.saga_type

    # グローバルメトリクスを更新
    global_metrics =
      state.global_metrics
      |> Map.update(:total_failed, 1, &(&1 + 1))
      |> Map.update(:active_sagas, 0, &max(&1 - 1, 0))

    # Sagaタイプ別メトリクスを更新
    saga_metrics =
      Map.update(state.saga_metrics, saga_type, default_saga_metrics(), fn metrics ->
        metrics
        |> Map.update(:total_failed, 1, &(&1 + 1))
        |> Map.update(:active_count, 0, &max(&1 - 1, 0))
        |> Map.put(:last_failed_at, DateTime.utc_now())
        |> Map.update(:failure_reasons, %{}, fn reasons ->
          reason_key = inspect(metadata[:reason])
          Map.update(reasons, reason_key, 1, &(&1 + 1))
        end)
      end)

    %{state | global_metrics: global_metrics, saga_metrics: saga_metrics}
  end

  defp handle_telemetry_event([:saga, :step_completed], measurements, metadata, state) do
    saga_type = metadata[:saga_type] || :unknown
    step_name = metadata.step_name
    duration = measurements[:duration] || 0

    # ステップメトリクスを更新
    step_metrics =
      Map.update(state.step_metrics, {saga_type, step_name}, default_step_metrics(), fn metrics ->
        metrics
        |> Map.update(:total_executed, 1, &(&1 + 1))
        |> Map.update(:total_succeeded, 1, &(&1 + 1))
        |> update_duration_stats(duration)
      end)

    %{state | step_metrics: step_metrics}
  end

  defp handle_telemetry_event([:saga, :step_timeout], _measurements, metadata, state) do
    saga_type = metadata[:saga_type] || :unknown
    step_name = metadata.step_name

    # グローバルメトリクスを更新
    global_metrics = Map.update(state.global_metrics, :total_timeouts, 1, &(&1 + 1))

    # ステップメトリクスを更新
    step_metrics =
      Map.update(state.step_metrics, {saga_type, step_name}, default_step_metrics(), fn metrics ->
        Map.update(metrics, :total_timeouts, 1, &(&1 + 1))
      end)

    %{state | global_metrics: global_metrics, step_metrics: step_metrics}
  end

  defp handle_telemetry_event([:saga, :step_compensated], _measurements, metadata, state) do
    saga_type = metadata[:saga_type] || :unknown
    step_name = metadata.step_name

    # グローバルメトリクスを更新
    _global_metrics = Map.update(state.global_metrics, :total_compensated, 1, &(&1 + 1))

    # ステップメトリクスを更新
    step_metrics =
      Map.update(state.step_metrics, {saga_type, step_name}, default_step_metrics(), fn metrics ->
        Map.update(metrics, :total_compensated, 1, &(&1 + 1))
      end)

    %{state | step_metrics: step_metrics}
  end

  defp handle_telemetry_event(_, _, _, state), do: state

  defp default_saga_metrics do
    %{
      total_started: 0,
      total_completed: 0,
      total_failed: 0,
      active_count: 0,
      duration_min: nil,
      duration_max: nil,
      duration_avg: nil,
      duration_sum: 0,
      duration_count: 0,
      failure_reasons: %{},
      last_started_at: nil,
      last_completed_at: nil,
      last_failed_at: nil
    }
  end

  defp default_step_metrics do
    %{
      total_executed: 0,
      total_succeeded: 0,
      total_timeouts: 0,
      total_compensated: 0,
      duration_min: nil,
      duration_max: nil,
      duration_avg: nil,
      duration_sum: 0,
      duration_count: 0
    }
  end

  defp update_duration_stats(metrics, duration) do
    metrics
    |> Map.update(:duration_sum, duration, &(&1 + duration))
    |> Map.update(:duration_count, 1, &(&1 + 1))
    |> Map.update(:duration_min, duration, &min(&1, duration))
    |> Map.update(:duration_max, duration, &max(&1, duration))
    |> Map.put(
      :duration_avg,
      (metrics.duration_sum + duration) / (metrics.duration_count + 1)
    )
  end

  defp summarize_saga_metrics(saga_metrics) do
    Enum.map(saga_metrics, fn {saga_type, metrics} ->
      success_rate =
        if metrics.total_started > 0 do
          metrics.total_completed / metrics.total_started * 100
        else
          0
        end

      {saga_type, Map.put(metrics, :success_rate, success_rate)}
    end)
    |> Map.new()
  end

  defp summarize_step_metrics(step_metrics) do
    Enum.map(step_metrics, fn {{saga_type, step_name}, metrics} ->
      success_rate =
        if metrics.total_executed > 0 do
          metrics.total_succeeded / metrics.total_executed * 100
        else
          0
        end

      timeout_rate =
        if metrics.total_executed > 0 do
          metrics.total_timeouts / metrics.total_executed * 100
        else
          0
        end

      enhanced_metrics =
        metrics
        |> Map.put(:success_rate, success_rate)
        |> Map.put(:timeout_rate, timeout_rate)

      {{saga_type, step_name}, enhanced_metrics}
    end)
    |> Map.new()
  end

  defp schedule_report do
    # 5分ごとにレポートを生成
    Process.send_after(self(), :generate_report, 5 * 60 * 1000)
  end

  defp generate_and_log_report(state) do
    Logger.info("""
    === Saga Monitor Report ===

    Global Metrics:
      Total Started: #{state.global_metrics.total_started}
      Total Completed: #{state.global_metrics.total_completed}
      Total Failed: #{state.global_metrics.total_failed}
      Total Timeouts: #{state.global_metrics.total_timeouts}
      Active Sagas: #{state.global_metrics.active_sagas}

    Top Failed Saga Types:
    #{format_top_failures(state.saga_metrics)}

    Slowest Steps:
    #{format_slowest_steps(state.step_metrics)}
    """)
  end

  defp format_top_failures(saga_metrics) do
    saga_metrics
    |> Enum.filter(fn {_type, metrics} -> metrics.total_failed > 0 end)
    |> Enum.sort_by(fn {_type, metrics} -> -metrics.total_failed end)
    |> Enum.take(5)
    |> Enum.map_join("\n", fn {type, metrics} ->
      "  #{type}: #{metrics.total_failed} failures"
    end)
  end

  defp format_slowest_steps(step_metrics) do
    step_metrics
    |> Enum.filter(fn {_key, metrics} -> metrics.duration_avg != nil end)
    |> Enum.sort_by(fn {_key, metrics} -> -metrics.duration_avg end)
    |> Enum.take(5)
    |> Enum.map_join("\n", fn {{saga_type, step_name}, metrics} ->
      "  #{saga_type}.#{step_name}: avg #{round(metrics.duration_avg)}ms"
    end)
  end

  defp init_state do
    %{
      saga_metrics: %{},
      step_metrics: %{},
      global_metrics: %{
        total_started: 0,
        total_completed: 0,
        total_failed: 0,
        total_compensated: 0,
        total_timeouts: 0,
        active_sagas: 0
      }
    }
  end
end
