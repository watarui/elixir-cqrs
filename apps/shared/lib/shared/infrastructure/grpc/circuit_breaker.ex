defmodule Shared.Infrastructure.Grpc.CircuitBreaker do
  @moduledoc """
  サーキットブレーカーパターンの実装
  
  連続的な障害を検出し、システムを保護するために
  一時的にリクエストをブロックします。
  
  状態遷移:
  - Closed -> Open: 失敗閾値に達した場合
  - Open -> HalfOpen: タイムアウト後
  - HalfOpen -> Closed: 成功した場合
  - HalfOpen -> Open: 失敗した場合
  """
  
  use GenServer
  require Logger
  
  @type state :: :closed | :open | :half_open
  
  @type circuit_state :: %{
    state: state(),
    failure_count: non_neg_integer(),
    success_count: non_neg_integer(),
    last_failure_time: integer() | nil,
    consecutive_successes: non_neg_integer()
  }
  
  @type options :: %{
    failure_threshold: pos_integer(),
    success_threshold: pos_integer(),
    timeout: pos_integer(),
    reset_timeout: pos_integer()
  }
  
  @default_options %{
    failure_threshold: 5,
    success_threshold: 2,
    timeout: 30_000,
    reset_timeout: 60_000
  }
  
  # Client API
  
  @doc """
  サーキットブレーカーを通して関数を実行します
  """
  @spec call(atom(), (() -> {:ok, any()} | {:error, any()})) :: {:ok, any()} | {:error, any()}
  def call(name, func) do
    case get_state(name) do
      :open ->
        record_metrics(name, :rejected)
        {:error, :circuit_open}
        
      state ->
        execute_with_circuit(name, func, state)
    end
  end
  
  @doc """
  サーキットブレーカーを開始します
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    options = Keyword.get(opts, :options, %{})
    GenServer.start_link(__MODULE__, options, name: name)
  end
  
  @doc """
  現在の状態を取得します
  """
  @spec get_state(atom()) :: state()
  def get_state(name) do
    GenServer.call(name, :get_state)
  end
  
  @doc """
  サーキットをリセットします（主にテスト用）
  """
  @spec reset(atom()) :: :ok
  def reset(name) do
    GenServer.call(name, :reset)
  end
  
  # Server callbacks
  
  @impl true
  def init(options) do
    options = Map.merge(@default_options, options)
    
    state = %{
      circuit_state: %{
        state: :closed,
        failure_count: 0,
        success_count: 0,
        last_failure_time: nil,
        consecutive_successes: 0
      },
      options: options,
      timers: %{}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    check_timeout(state)
    {:reply, state.circuit_state.state, state}
  end
  
  @impl true
  def handle_call(:reset, _from, state) do
    new_state = %{state | 
      circuit_state: %{
        state: :closed,
        failure_count: 0,
        success_count: 0,
        last_failure_time: nil,
        consecutive_successes: 0
      },
      timers: cancel_all_timers(state.timers)
    }
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:record_success, latency}, _from, state) do
    new_state = handle_success(state, latency)
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call({:record_failure, reason}, _from, state) do
    new_state = handle_failure(state, reason)
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_info({:timeout, :half_open}, state) do
    new_circuit_state = %{state.circuit_state | state: :half_open}
    Logger.info("Circuit breaker transitioning to half-open state")
    {:noreply, %{state | circuit_state: new_circuit_state}}
  end
  
  @impl true
  def handle_info({:timeout, :reset}, state) do
    new_circuit_state = %{state.circuit_state | 
      state: :closed,
      failure_count: 0,
      success_count: 0,
      consecutive_successes: 0
    }
    Logger.info("Circuit breaker reset to closed state")
    {:noreply, %{state | circuit_state: new_circuit_state}}
  end
  
  # Private functions
  
  defp execute_with_circuit(name, func, state) do
    start_time = System.monotonic_time(:millisecond)
    
    case func.() do
      {:ok, result} = success ->
        latency = System.monotonic_time(:millisecond) - start_time
        GenServer.call(name, {:record_success, latency})
        record_metrics(name, :success, latency)
        success
        
      {:error, _reason} = error ->
        GenServer.call(name, {:record_failure, error})
        record_metrics(name, :failure)
        error
    end
  end
  
  defp handle_success(state, latency) do
    circuit_state = state.circuit_state
    
    new_circuit_state = case circuit_state.state do
      :half_open ->
        consecutive = circuit_state.consecutive_successes + 1
        
        if consecutive >= state.options.success_threshold do
          Logger.info("Circuit breaker closing after #{consecutive} successful calls")
          %{circuit_state | 
            state: :closed,
            failure_count: 0,
            success_count: circuit_state.success_count + 1,
            consecutive_successes: 0
          }
        else
          %{circuit_state | 
            success_count: circuit_state.success_count + 1,
            consecutive_successes: consecutive
          }
        end
        
      :closed ->
        %{circuit_state | 
          success_count: circuit_state.success_count + 1,
          failure_count: max(0, circuit_state.failure_count - 1)
        }
        
      :open ->
        circuit_state
    end
    
    %{state | circuit_state: new_circuit_state}
  end
  
  defp handle_failure(state, reason) do
    circuit_state = state.circuit_state
    now = System.monotonic_time(:millisecond)
    
    new_circuit_state = case circuit_state.state do
      :closed ->
        failure_count = circuit_state.failure_count + 1
        
        if failure_count >= state.options.failure_threshold do
          Logger.warning("Circuit breaker opening after #{failure_count} failures")
          timer_ref = Process.send_after(self(), {:timeout, :half_open}, state.options.timeout)
          
          %{circuit_state | 
            state: :open,
            failure_count: failure_count,
            last_failure_time: now,
            consecutive_successes: 0
          }
        else
          %{circuit_state | 
            failure_count: failure_count,
            last_failure_time: now
          }
        end
        
      :half_open ->
        Logger.warning("Circuit breaker reopening after failure in half-open state")
        timer_ref = Process.send_after(self(), {:timeout, :half_open}, state.options.timeout)
        
        %{circuit_state | 
          state: :open,
          failure_count: circuit_state.failure_count + 1,
          last_failure_time: now,
          consecutive_successes: 0
        }
        
      :open ->
        %{circuit_state | 
          failure_count: circuit_state.failure_count + 1,
          last_failure_time: now
        }
    end
    
    %{state | circuit_state: new_circuit_state}
  end
  
  defp check_timeout(state) do
    case state.circuit_state.state do
      :open when not is_nil(state.circuit_state.last_failure_time) ->
        elapsed = System.monotonic_time(:millisecond) - state.circuit_state.last_failure_time
        if elapsed >= state.options.timeout do
          send(self(), {:timeout, :half_open})
        end
      _ ->
        :ok
    end
  end
  
  defp cancel_all_timers(timers) do
    Enum.each(timers, fn {_key, ref} -> Process.cancel_timer(ref) end)
    %{}
  end
  
  defp record_metrics(name, status, latency \\ nil) do
    metadata = %{
      circuit_breaker: name,
      status: status
    }
    
    measurements = if latency do
      %{latency: latency, count: 1}
    else
      %{count: 1}
    end
    
    :telemetry.execute(
      [:circuit_breaker, :call],
      measurements,
      metadata
    )
  end
end