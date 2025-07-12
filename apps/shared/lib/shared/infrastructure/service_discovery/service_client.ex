defmodule Shared.Infrastructure.ServiceDiscovery.ServiceClient do
  @moduledoc """
  サービス間通信のためのクライアント

  サービスディスカバリと統合し、自動的な負荷分散、
  リトライ、サーキットブレーカーを提供する。
  """

  alias Shared.Infrastructure.Resilience.CircuitBreaker
  alias Shared.Infrastructure.Retry.RetryStrategy
  alias Shared.Infrastructure.ServiceDiscovery.ServiceRegistry

  require Logger

  @default_timeout 30_000
  @default_retry_opts %{
    max_attempts: 3,
    base_delay: 1_000,
    max_delay: 5_000,
    backoff_type: :exponential
  }

  @doc """
  サービスにリクエストを送信する

  ## Parameters
  - `service_name` - サービス名
  - `method` - HTTPメソッド（:get, :post, :put, :delete）
  - `path` - リクエストパス
  - `opts` - オプション
    - `:body` - リクエストボディ
    - `:headers` - ヘッダー
    - `:query` - クエリパラメータ
    - `:timeout` - タイムアウト（ミリ秒）
    - `:retry` - リトライオプション
    - `:circuit_breaker` - サーキットブレーカー名
    
  ## Examples
      ServiceClient.request("user-service", :get, "/users/123")
      
      ServiceClient.request("order-service", :post, "/orders", 
        body: %{user_id: "123", items: [...]}
      )
  """
  @spec request(String.t(), atom(), String.t(), keyword()) ::
          {:ok, any()} | {:error, term()}
  def request(service_name, method, path, opts \\ []) do
    circuit_breaker = Keyword.get(opts, :circuit_breaker, "#{service_name}_circuit")

    # サーキットブレーカー経由で実行
    CircuitBreaker.call(circuit_breaker, fn ->
      do_request_with_retry(service_name, method, path, opts)
    end)
  end

  @doc """
  特定のサービスインスタンスにリクエストを送信する

  サービスディスカバリを使用せず、直接指定されたインスタンスに送信
  """
  @spec request_instance(String.t(), integer(), atom(), String.t(), keyword()) ::
          {:ok, any()} | {:error, term()}
  def request_instance(host, port, method, path, opts \\ []) do
    url = build_url(host, port, path, opts)
    headers = build_headers(opts)
    body = encode_body(opts)
    timeout_opts = build_timeout_opts(opts)

    # Finchを使用
    request = Finch.build(method, url, headers, body)

    case Finch.request(request, Shared.Finch, timeout_opts) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        decode_response(resp_body)

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  サービスのヘルスチェックを実行する
  """
  @spec health_check(String.t()) :: {:ok, map()} | {:error, term()}
  def health_check(service_name) do
    case ServiceRegistry.get_instance(service_name) do
      {:ok, instance} ->
        url = instance.health_check_url || "http://#{instance.host}:#{instance.port}/health"

        request = Finch.build(:get, url)

        case Finch.request(request, Shared.Finch, receive_timeout: 5_000) do
          {:ok, %{status: 200, body: body}} ->
            decode_response(body)

          {:ok, %{status: status}} ->
            {:error, {:unhealthy, status}}

          {:error, reason} ->
            {:error, reason}
        end

      error ->
        error
    end
  end

  @doc """
  すべての健康なサービスインスタンスを取得する
  """
  @spec discover_all(String.t()) :: {:ok, [map()]} | {:error, term()}
  def discover_all(service_name) do
    ServiceRegistry.discover(service_name)
  end

  # Private functions

  defp do_request_with_retry(service_name, method, path, opts) do
    retry_opts = Keyword.get(opts, :retry, @default_retry_opts)

    RetryStrategy.execute_with_condition(
      fn ->
        do_request_with_discovery(service_name, method, path, opts)
      end,
      fn error ->
        # ネットワークエラーやタイムアウトの場合はリトライ
        case error do
          {:error, :no_healthy_instances} -> false
          {:error, {:http_error, status, _}} when status in 400..499 -> false
          _ -> true
        end
      end,
      retry_opts
    )
  end

  defp do_request_with_discovery(service_name, method, path, opts) do
    with {:ok, instance} <- ServiceRegistry.get_instance(service_name) do
      url = build_url(instance.host, instance.port, path, opts)
      headers = build_headers(opts)
      body = encode_body(opts)
      timeout_opts = build_timeout_opts(opts)

      Logger.debug("Requesting #{method} #{url}")

      # Finchを使用
      request = Finch.build(method, url, headers, body)
      start_time = System.monotonic_time()

      case Finch.request(request, Shared.Finch, timeout_opts) do
        {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
          # 成功
          duration = System.monotonic_time() - start_time

          :telemetry.execute(
            [:service_client, :request, :success],
            %{duration: System.convert_time_unit(duration, :native, :millisecond)},
            %{service: service_name, method: method, status: status}
          )

          decode_response(resp_body)

        {:ok, %{status: status, body: resp_body}} ->
          # HTTPエラー
          :telemetry.execute(
            [:service_client, :request, :error],
            %{count: 1},
            %{service: service_name, method: method, status: status}
          )

          {:error, {:http_error, status, resp_body}}

        {:error, reason} ->
          # ネットワークエラー
          :telemetry.execute(
            [:service_client, :request, :failure],
            %{count: 1},
            %{service: service_name, method: method, reason: reason}
          )

          {:error, reason}
      end
    end
  end

  defp build_url(host, port, path, opts) do
    query = Keyword.get(opts, :query, %{})
    base_url = "http://#{host}:#{port}#{path}"

    if map_size(query) > 0 do
      query_string = URI.encode_query(query)
      "#{base_url}?#{query_string}"
    else
      base_url
    end
  end

  defp build_headers(opts) do
    default_headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    custom_headers = Keyword.get(opts, :headers, [])

    Keyword.merge(default_headers, custom_headers)
  end

  defp encode_body(opts) do
    case Keyword.get(opts, :body) do
      nil -> ""
      body when is_binary(body) -> body
      body -> Jason.encode!(body)
    end
  end

  defp decode_response(""), do: {:ok, nil}

  defp decode_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      # JSONでない場合はそのまま返す
      {:error, _} -> {:ok, body}
    end
  end

  defp build_timeout_opts(opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    [
      receive_timeout: timeout
    ]
  end
end
