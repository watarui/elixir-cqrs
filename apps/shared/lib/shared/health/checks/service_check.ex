defmodule Shared.Health.Checks.ServiceCheck do
  @moduledoc """
  各サービスの稼働状況チェック

  重要なGenServerやSupervisorの稼働状況を確認します。
  """

  require Logger

  @critical_services [
    {:event_bus, Shared.Infrastructure.EventBus},
    {:command_bus, CommandService.Infrastructure.CommandBus},
    {:query_bus, QueryService.Infrastructure.QueryBus},
    {:saga_executor, Shared.Infrastructure.Saga.SagaExecutor},
    {:service_registry, Shared.Infrastructure.ServiceDiscovery.ServiceRegistry}
  ]

  @optional_services [
    {:saga_monitor, Shared.Infrastructure.Saga.SagaMonitor},
    {:saga_timeout_manager, Shared.Infrastructure.Saga.SagaTimeoutManager},
    {:circuit_breaker_supervisor, Shared.Infrastructure.Resilience.CircuitBreakerSupervisor},
    {:event_archiver, Shared.Infrastructure.EventStore.EventArchiver}
  ]

  @doc """
  全サービスの稼働状況を確認
  """
  def check do
    critical_results = check_services(@critical_services)
    optional_results = check_services(@optional_services)

    all_results = Map.merge(critical_results, optional_results)

    critical_failures =
      @critical_services
      |> Enum.filter(fn {name, _} ->
        Map.get(critical_results, name) != :running
      end)
      |> Enum.map(fn {name, _} -> name end)

    if Enum.empty?(critical_failures) do
      # オプショナルサービスの一部が停止している場合は degraded
      optional_failures =
        @optional_services
        |> Enum.filter(fn {name, _} ->
          Map.get(optional_results, name) != :running
        end)

      if Enum.empty?(optional_failures) do
        {:ok, all_results}
      else
        {:degraded, "Optional services not running: #{inspect(optional_failures)}", all_results}
      end
    else
      {:error, "Critical services not running: #{inspect(critical_failures)}", all_results}
    end
  end

  defp check_services(services) do
    services
    |> Enum.map(fn {name, module} ->
      status = check_process(module)
      {name, status}
    end)
    |> Enum.into(%{})
  end

  defp check_process(module) do
    case Process.whereis(module) do
      nil ->
        # プロセス名で見つからない場合、Registry経由で探す
        case Registry.lookup(:service_registry, module) do
          [{pid, _}] when is_pid(pid) ->
            if Process.alive?(pid), do: :running, else: :dead

          _ ->
            :not_started
        end

      pid when is_pid(pid) ->
        if Process.alive?(pid), do: :running, else: :dead
    end
  rescue
    _ -> :error
  end
end
