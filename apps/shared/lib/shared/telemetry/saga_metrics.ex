defmodule Shared.Telemetry.SagaMetrics do
  @moduledoc """
  サガ専用のメトリクス収集
  """

  use GenServer

  alias Shared.Telemetry.Metrics

  # 10秒ごとに更新
  @update_interval 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_update()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:update_metrics, state) do
    # アクティブなサガの数を取得して発行
    active_sagas = Shared.Infrastructure.Saga.SagaCoordinator.get_active_sagas()

    # サガタイプごとにグループ化してカウント
    saga_counts =
      active_sagas
      |> Enum.group_by(fn {_, {saga_module, _}} -> saga_module end)
      |> Enum.map(fn {saga_module, sagas} ->
        {saga_module |> Module.split() |> List.last(), length(sagas)}
      end)

    # メトリクスを発行
    Enum.each(saga_counts, fn {saga_type, count} ->
      Metrics.emit_saga_active_metric(saga_type, count)
    end)

    schedule_update()
    {:noreply, state}
  end

  defp schedule_update do
    Process.send_after(self(), :update_metrics, @update_interval)
  end
end
