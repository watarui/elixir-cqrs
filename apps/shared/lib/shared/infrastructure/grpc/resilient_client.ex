defmodule Shared.Infrastructure.Grpc.ResilientClient do
  @moduledoc """
  リトライとサーキットブレーカーを統合したレジリエントなgRPCクライアント

  このモジュールは、gRPC呼び出しに対して以下の機能を提供します：
  - 自動リトライ（エクスポネンシャルバックオフ付き）
  - サーキットブレーカー
  - タイムアウト設定
  - 包括的なメトリクスとロギング
  """

  require Logger
  alias Shared.Infrastructure.Grpc.{CircuitBreaker, RetryStrategy}

  @type call_options :: %{
          timeout: pos_integer(),
          retry: map(),
          circuit_breaker: atom() | nil,
          metadata: map()
        }

  @default_options %{
    timeout: 5000,
    retry: %{},
    circuit_breaker: nil,
    metadata: %{}
  }

  @doc """
  レジリエントなgRPC呼び出しを実行します

  ## オプション

  - `:timeout` - タイムアウト（ミリ秒）
  - `:retry` - リトライオプション（RetryStrategyを参照）
  - `:circuit_breaker` - 使用するサーキットブレーカーの名前
  - `:metadata` - メトリクスとロギング用のメタデータ

  ## 例

      ResilientClient.call(
        fn -> ProductQuery.Stub.get_product(channel, request) end,
        %{
          timeout: 3000,
          retry: %{max_attempts: 3},
          circuit_breaker: :product_service_cb,
          metadata: %{operation: "get_product", product_id: id}
        }
      )
  """
  @spec call((-> {:ok, any()} | {:error, any()}), map()) :: {:ok, any()} | {:error, any()}
  def call(func, options \\ %{}) do
    options = Map.merge(@default_options, options)
    start_time = System.monotonic_time(:millisecond)

    # サーキットブレーカーがある場合は、それを通して実行
    result =
      if options.circuit_breaker do
        CircuitBreaker.call(options.circuit_breaker, fn ->
          execute_with_retry_and_timeout(func, options)
        end)
      else
        execute_with_retry_and_timeout(func, options)
      end

    duration = System.monotonic_time(:millisecond) - start_time
    record_call_metrics(result, duration, options.metadata)

    result
  end

  @doc """
  サーキットブレーカー付きのgRPCスタブを作成します

  このヘルパー関数は、既存のgRPCスタブモジュールをラップして、
  すべての呼び出しに自動的にレジリエンス機能を追加します。
  """
  defmacro create_resilient_stub(stub_module, circuit_breaker_name, default_options \\ %{}) do
    quote do
      defmodule unquote(Module.concat(stub_module, Resilient)) do
        @stub_module unquote(stub_module)
        @circuit_breaker unquote(circuit_breaker_name)
        @default_options unquote(Macro.escape(default_options))

        def __info__(:functions) do
          @stub_module.__info__(:functions)
        end

        def unquote(:"$handle_undefined_function")(func_name, args) do
          [channel | rest_args] = args

          options =
            Map.merge(@default_options, %{
              circuit_breaker: @circuit_breaker,
              metadata: %{
                stub: @stub_module,
                function: func_name
              }
            })

          Shared.Infrastructure.Grpc.ResilientClient.call(
            fn -> apply(@stub_module, func_name, args) end,
            options
          )
        end
      end
    end
  end

  # Private functions

  defp execute_with_retry_and_timeout(func, options) do
    timeout_ref = make_ref()
    timer_ref = Process.send_after(self(), {:timeout, timeout_ref}, options.timeout)

    task =
      Task.async(fn ->
        RetryStrategy.with_retry(func, options.retry)
      end)

    result =
      case Task.yield(task, options.timeout) || Task.shutdown(task) do
        {:ok, result} ->
          result

        nil ->
          Logger.error("gRPC call timed out after #{options.timeout}ms",
            metadata: options.metadata
          )

          {:error, :timeout}

        {:exit, reason} ->
          Logger.error("gRPC call crashed",
            reason: inspect(reason),
            metadata: options.metadata
          )

          {:error, {:crashed, reason}}
      end

    Process.cancel_timer(timer_ref)
    result
  end

  defp record_call_metrics({:ok, _}, duration, metadata) do
    :telemetry.execute(
      [:grpc, :client, :call],
      %{duration: duration},
      Map.put(metadata, :status, :success)
    )
  end

  defp record_call_metrics({:error, reason}, duration, metadata) do
    status =
      case reason do
        :circuit_open -> :circuit_open
        :timeout -> :timeout
        %GRPC.RPCError{status: status} -> status
        _ -> :unknown_error
      end

    :telemetry.execute(
      [:grpc, :client, :call],
      %{duration: duration},
      Map.merge(metadata, %{status: status, error: true})
    )
  end
end
