defmodule Shared.Infrastructure.ServiceDiscovery.ServiceRegistry do
  @moduledoc """
  サービスディスカバリのためのレジストリ

  マイクロサービス間の動的なサービス発見と
  ヘルスチェック機能を提供する。
  """

  use GenServer
  require Logger

  # 30秒
  @health_check_interval 30_000
  # 3回連続失敗でunhealthy
  @unhealthy_threshold 3

  # サービス情報の構造体
  defmodule ServiceInfo do
    @moduledoc """
    登録されたサービスインスタンスを表す構造体
    """
    @enforce_keys [:name, :host, :port, :metadata]
    defstruct [
      :name,
      :host,
      :port,
      :metadata,
      :health_check_url,
      :registered_at,
      :last_health_check,
      :health_status,
      :failed_checks,
      :instance_id
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            host: String.t(),
            port: integer(),
            metadata: map(),
            health_check_url: String.t() | nil,
            registered_at: DateTime.t(),
            last_health_check: DateTime.t() | nil,
            health_status: :healthy | :unhealthy | :unknown,
            failed_checks: non_neg_integer(),
            instance_id: String.t()
          }
  end

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  サービスを登録する

  ## Parameters
  - `name` - サービス名
  - `host` - ホスト名またはIPアドレス
  - `port` - ポート番号
  - `opts` - オプション
    - `:metadata` - メタデータ
    - `:health_check_url` - ヘルスチェック用URL
    - `:instance_id` - インスタンスID（デフォルトは自動生成）
  """
  @spec register(String.t(), String.t(), integer(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def register(name, host, port, opts \\ []) do
    GenServer.call(__MODULE__, {:register, name, host, port, opts})
  end

  @doc """
  サービスの登録を解除する
  """
  @spec deregister(String.t(), String.t()) :: :ok
  def deregister(name, instance_id) do
    GenServer.call(__MODULE__, {:deregister, name, instance_id})
  end

  @doc """
  サービスを検索する

  健康なインスタンスのみを返す
  """
  @spec discover(String.t()) :: {:ok, [ServiceInfo.t()]} | {:error, :not_found}
  def discover(name) do
    GenServer.call(__MODULE__, {:discover, name})
  end

  @doc """
  特定のサービスインスタンスを取得する

  ラウンドロビンで健康なインスタンスを選択
  """
  @spec get_instance(String.t()) :: {:ok, ServiceInfo.t()} | {:error, :no_healthy_instances}
  def get_instance(name) do
    GenServer.call(__MODULE__, {:get_instance, name})
  end

  @doc """
  すべてのサービスを取得する
  """
  @spec list_services() :: {:ok, map()}
  def list_services do
    GenServer.call(__MODULE__, :list_services)
  end

  @doc """
  ヘルスチェックを手動で実行する
  """
  @spec health_check(String.t()) :: :ok
  def health_check(name) do
    GenServer.cast(__MODULE__, {:health_check, name})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # 定期的なヘルスチェックをスケジュール
    schedule_health_checks()

    state = %{
      # service_name -> [ServiceInfo]
      services: %{},
      # ラウンドロビン用のカウンター
      round_robin_counters: %{},
      # 統計情報
      stats: %{
        registrations: 0,
        deregistrations: 0,
        health_checks: 0,
        failures: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register, name, host, port, opts}, _from, state) do
    metadata = Keyword.get(opts, :metadata, %{})
    health_check_url = Keyword.get(opts, :health_check_url, "http://#{host}:#{port}/health")
    instance_id = Keyword.get(opts, :instance_id, generate_instance_id(name, host, port))

    service_info = %ServiceInfo{
      name: name,
      host: host,
      port: port,
      metadata: metadata,
      health_check_url: health_check_url,
      registered_at: DateTime.utc_now(),
      health_status: :unknown,
      failed_checks: 0,
      instance_id: instance_id
    }

    # サービスリストに追加
    services =
      Map.update(state.services, name, [service_info], fn instances ->
        # 同じインスタンスIDがあれば更新、なければ追加
        case Enum.find_index(instances, &(&1.instance_id == instance_id)) do
          nil -> [service_info | instances]
          index -> List.replace_at(instances, index, service_info)
        end
      end)

    new_state =
      state
      |> Map.put(:services, services)
      |> update_in([:stats, :registrations], &(&1 + 1))

    Logger.info("Service registered: #{name} at #{host}:#{port} (#{instance_id})")

    # すぐにヘルスチェックを実行
    send(self(), {:check_health, name, instance_id})

    :telemetry.execute(
      [:service_registry, :registered],
      %{count: 1},
      %{service: name, instance_id: instance_id}
    )

    {:reply, {:ok, instance_id}, new_state}
  end

  @impl true
  def handle_call({:deregister, name, instance_id}, _from, state) do
    services =
      Map.update(state.services, name, [], fn instances ->
        Enum.reject(instances, &(&1.instance_id == instance_id))
      end)

    # 空になったサービスは削除
    services = if services[name] == [], do: Map.delete(services, name), else: services

    new_state =
      state
      |> Map.put(:services, services)
      |> update_in([:stats, :deregistrations], &(&1 + 1))

    Logger.info("Service deregistered: #{name} (#{instance_id})")

    :telemetry.execute(
      [:service_registry, :deregistered],
      %{count: 1},
      %{service: name, instance_id: instance_id}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:discover, name}, _from, state) do
    case Map.get(state.services, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      instances ->
        # 健康なインスタンスのみを返す
        healthy_instances = Enum.filter(instances, &(&1.health_status == :healthy))

        if Enum.empty?(healthy_instances) do
          {:reply, {:error, :no_healthy_instances}, state}
        else
          {:reply, {:ok, healthy_instances}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_instance, name}, _from, state) do
    case Map.get(state.services, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      instances ->
        # 健康なインスタンスのみ
        healthy_instances = Enum.filter(instances, &(&1.health_status == :healthy))

        if Enum.empty?(healthy_instances) do
          {:reply, {:error, :no_healthy_instances}, state}
        else
          # ラウンドロビンで選択
          counter = Map.get(state.round_robin_counters, name, 0)
          index = rem(counter, length(healthy_instances))
          instance = Enum.at(healthy_instances, index)

          # カウンターを更新
          new_state = put_in(state, [:round_robin_counters, name], counter + 1)

          {:reply, {:ok, instance}, new_state}
        end
    end
  end

  @impl true
  def handle_call(:list_services, _from, state) do
    service_summary =
      state.services
      |> Enum.map(fn {name, instances} ->
        healthy_count = Enum.count(instances, &(&1.health_status == :healthy))
        unhealthy_count = Enum.count(instances, &(&1.health_status == :unhealthy))
        unknown_count = Enum.count(instances, &(&1.health_status == :unknown))

        {name,
         %{
           total_instances: length(instances),
           healthy: healthy_count,
           unhealthy: unhealthy_count,
           unknown: unknown_count,
           instances: instances
         }}
      end)
      |> Map.new()

    {:reply, {:ok, service_summary}, state}
  end

  @impl true
  def handle_cast({:health_check, name}, state) do
    case Map.get(state.services, name) do
      nil ->
        {:noreply, state}

      instances ->
        # すべてのインスタンスのヘルスチェックを実行
        Enum.each(instances, fn instance ->
          send(self(), {:check_health, name, instance.instance_id})
        end)

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:perform_health_checks, state) do
    # すべてのサービスのヘルスチェックを実行
    Enum.each(state.services, fn {name, instances} ->
      Enum.each(instances, fn instance ->
        send(self(), {:check_health, name, instance.instance_id})
      end)
    end)

    schedule_health_checks()
    {:noreply, state}
  end

  @impl true
  def handle_info({:check_health, name, instance_id}, state) do
    case get_in(state.services, [name]) do
      nil ->
        {:noreply, state}

      instances ->
        case Enum.find_index(instances, &(&1.instance_id == instance_id)) do
          nil ->
            {:noreply, state}

          index ->
            instance = Enum.at(instances, index)

            # バックグラウンドでヘルスチェックを実行
            Task.start(fn ->
              result = perform_health_check(instance)
              send(__MODULE__, {:health_check_result, name, instance_id, result})
            end)

            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info({:health_check_result, name, instance_id, result}, state) do
    case get_in(state.services, [name]) do
      nil ->
        {:noreply, state}

      instances ->
        updated_instances =
          Enum.map(instances, fn instance ->
            if instance.instance_id == instance_id do
              update_health_status(instance, result)
            else
              instance
            end
          end)

        new_state =
          state
          |> put_in([:services, name], updated_instances)
          |> update_in([:stats, :health_checks], &(&1 + 1))

        new_state =
          if result == :error do
            update_in(new_state, [:stats, :failures], &(&1 + 1))
          else
            new_state
          end

        {:noreply, new_state}
    end
  end

  # Private functions

  defp generate_instance_id(name, host, port) do
    timestamp = System.unique_integer([:positive, :monotonic])
    "#{name}_#{host}_#{port}_#{timestamp}"
  end

  defp schedule_health_checks do
    Process.send_after(self(), :perform_health_checks, @health_check_interval)
  end

  defp perform_health_check(%ServiceInfo{health_check_url: nil}), do: :ok

  defp perform_health_check(%ServiceInfo{health_check_url: url}) do
    # Finchを使用してヘルスチェック
    request = Finch.build(:get, url)

    case Finch.request(request, Shared.Finch, receive_timeout: 5_000) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  defp update_health_status(instance, :ok) do
    %{instance | health_status: :healthy, failed_checks: 0, last_health_check: DateTime.utc_now()}
  end

  defp update_health_status(instance, :error) do
    failed_checks = instance.failed_checks + 1

    health_status =
      if failed_checks >= @unhealthy_threshold do
        :unhealthy
      else
        instance.health_status
      end

    %{
      instance
      | health_status: health_status,
        failed_checks: failed_checks,
        last_health_check: DateTime.utc_now()
    }
  end
end
