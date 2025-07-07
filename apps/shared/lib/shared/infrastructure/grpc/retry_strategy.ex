defmodule Shared.Infrastructure.Grpc.RetryStrategy do
  @moduledoc """
  gRPC呼び出しのリトライ戦略を実装するモジュール

  エクスポネンシャルバックオフとジッターを使用して、
  一時的な障害に対する耐性を提供します。
  """

  require Logger

  @type retry_options :: %{
          max_attempts: pos_integer(),
          initial_delay: pos_integer(),
          max_delay: pos_integer(),
          multiplier: float(),
          jitter: boolean(),
          retryable_errors: [atom()]
        }

  @default_options %{
    max_attempts: 3,
    initial_delay: 100,
    max_delay: 5000,
    multiplier: 2.0,
    jitter: true,
    retryable_errors: [:unavailable, :deadline_exceeded, :resource_exhausted, :aborted, :internal]
  }

  @doc """
  リトライ可能な関数を実行します
  """
  @spec with_retry((-> {:ok, any()} | {:error, any()}), map()) :: {:ok, any()} | {:error, any()}
  def with_retry(func, options \\ %{}) do
    options = Map.merge(@default_options, options)
    do_retry(func, options, 1)
  end

  defp do_retry(func, options, attempt) do
    start_time = System.monotonic_time(:millisecond)

    case func.() do
      {:ok, result} ->
        record_retry_metrics(:success, attempt, System.monotonic_time(:millisecond) - start_time)
        {:ok, result}

      {:error, %GRPC.RPCError{status: status} = error} ->
        if should_retry?(status, options.retryable_errors, attempt, options.max_attempts) do
          delay = calculate_delay(attempt, options)

          Logger.warning(
            "gRPC call failed with #{status}, retrying in #{delay}ms (attempt #{attempt}/#{options.max_attempts})",
            error: inspect(error)
          )

          Process.sleep(delay)
          record_retry_metrics(:retry, attempt, System.monotonic_time(:millisecond) - start_time)
          do_retry(func, options, attempt + 1)
        else
          Logger.error("gRPC call failed permanently after #{attempt} attempts",
            error: inspect(error)
          )

          record_retry_metrics(
            :failure,
            attempt,
            System.monotonic_time(:millisecond) - start_time
          )

          {:error, error}
        end

      {:error, reason} = error ->
        Logger.error("Non-gRPC error occurred, not retrying",
          error: inspect(reason)
        )

        record_retry_metrics(:failure, attempt, System.monotonic_time(:millisecond) - start_time)
        error
    end
  end

  defp should_retry?(status, retryable_errors, attempt, max_attempts) do
    attempt < max_attempts && status in retryable_errors
  end

  defp calculate_delay(attempt, %{
         initial_delay: initial,
         max_delay: max,
         multiplier: mult,
         jitter: jitter
       }) do
    delay = min(initial * :math.pow(mult, attempt - 1), max) |> round()

    if jitter do
      # 0.5から1.5の間のランダムな係数を適用
      jitter_factor = 0.5 + :rand.uniform()
      round(delay * jitter_factor)
    else
      delay
    end
  end

  defp record_retry_metrics(status, attempt, duration) do
    :telemetry.execute(
      [:grpc, :retry],
      %{
        duration: duration,
        attempt_count: attempt
      },
      %{
        status: status
      }
    )
  end
end
