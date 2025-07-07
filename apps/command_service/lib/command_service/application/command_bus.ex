defmodule CommandService.Application.CommandBus do
  @moduledoc """
  コマンドバス（メディエーターパターンの実装）
  
  コマンドを適切なハンドラーにルーティングし、実行結果を返します
  """

  use GenServer
  require Logger

  alias CommandService.Application.Handlers.{
    ProductCommandHandler,
    CategoryCommandHandler,
    OrderCommandHandler
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  コマンドを実行する
  """
  @spec execute(command :: struct()) :: {:ok, any()} | {:error, term()}
  def execute(command) do
    GenServer.call(get_server(), {:execute, command})
  end
  
  @doc """
  コマンドをディスパッチする（executeのエイリアス）
  """
  @spec dispatch(command :: struct()) :: {:ok, any()} | {:error, term()}
  def dispatch(command) do
    execute(command)
  end

  @doc """
  コマンドを非同期で実行する
  """
  @spec execute_async(command :: struct()) :: :ok
  def execute_async(command) do
    GenServer.cast(get_server(), {:execute_async, command})
  end

  # Server callbacks

  @impl GenServer
  def init(:ok) do
    # ハンドラーレジストリを初期化
    registry = build_handler_registry()
    {:ok, %{registry: registry}}
  end

  @impl GenServer
  def handle_call({:execute, command}, _from, state) do
    result = execute_command(command, state.registry)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_cast({:execute_async, command}, state) do
    # 非同期実行（結果は無視）
    spawn(fn ->
      execute_command(command, state.registry)
    end)
    {:noreply, state}
  end

  # Private functions

  defp get_server do
    case Process.whereis(__MODULE__) do
      nil -> 
        {:ok, pid} = start_link(name: __MODULE__)
        pid
      pid -> 
        pid
    end
  end

  defp build_handler_registry do
    handlers = [
      ProductCommandHandler,
      CategoryCommandHandler,
      OrderCommandHandler
    ]

    Enum.reduce(handlers, %{}, fn handler, acc ->
      Enum.reduce(handler.command_types(), acc, fn command_type, inner_acc ->
        Map.put(inner_acc, command_type, handler)
      end)
    end)
  end

  defp execute_command(command, registry) do
    command_type = command.__struct__
    
    # Telemetryスパンとメトリクス
    require Shared.Telemetry.Span, as: Span
    
    Span.with_span "command.execute", %{command_type: inspect(command_type)} do
      start_time = System.monotonic_time()
      
      result = case Map.get(registry, command_type) do
        nil ->
          {:error, "No handler found for command: #{inspect(command_type)}"}
        
        handler ->
          Logger.info("Executing command #{inspect(command_type)} with handler #{inspect(handler)}")
          
          try do
            handler.handle_command(command)
          rescue
            e ->
              Logger.error("Error executing command: #{inspect(e)}")
              {:error, Exception.message(e)}
          end
      end
      
      # メトリクスを記録
      duration = System.monotonic_time() - start_time
      status = case result do
        {:ok, _} -> :success
        {:error, _} -> :error
      end
      
      :telemetry.execute(
        [:command, :execute, :stop],
        %{duration: duration},
        %{command_type: inspect(command_type), status: status}
      )
      
      result
    end
  end
end