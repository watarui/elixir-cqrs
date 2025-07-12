defmodule Shared.Telemetry.Tracing.Config do
  @moduledoc """
  OpenTelemetry の詳細設定

  分散トレーシングのための拡張設定を提供します。
  """

  @doc """
  OpenTelemetry のトレーサープロバイダーを設定する
  """
  def configure_tracer_provider do
    # サービス名の設定
    service_name = Application.get_env(:opentelemetry, :service_name, "elixir-cqrs")
    service_version = Application.get_env(:opentelemetry, :service_version, "1.0.0")
    environment = Application.get_env(:opentelemetry, :environment, "development")

    # リソース属性の設定
    resource_attributes = %{
      "service.name" => service_name,
      "service.version" => service_version,
      "deployment.environment" => environment,
      "telemetry.sdk.language" => "elixir",
      "telemetry.sdk.name" => "opentelemetry",
      "host.name" => System.get_env("HOSTNAME", node() |> to_string())
    }

    # プロセッサーの設定
    processors = [
      # バッチプロセッサー
      {:otel_batch_processor,
       %{
         # バッチサイズ
         max_queue_size: 2048,
         scheduled_delay_ms: 5000,
         max_export_batch_size: 512,
         # エクスポーター設定
         exporter: configure_exporter()
       }},
      # 属性プロセッサー（機密情報のフィルタリング）
      {:otel_attribute_processor,
       %{
         actions: [
           # パスワードやトークンを除外
           {:delete, ~r/password|token|secret/i},
           # PII（個人識別情報）をマスク
           {:update, ~r/email/, &mask_email/1},
           {:update, ~r/phone/, &mask_phone/1}
         ]
       }}
    ]

    # サンプラーの設定
    sampler = configure_sampler()

    # プロパゲーターの設定
    propagators = [:trace_context, :baggage, :b3]

    %{
      resource: resource_attributes,
      processors: processors,
      sampler: sampler,
      propagators: propagators
    }
  end

  @doc """
  エクスポーターを設定する
  """
  def configure_exporter do
    endpoint = Application.get_env(:opentelemetry, :otlp_endpoint, "http://localhost:4318")
    protocol = Application.get_env(:opentelemetry, :otlp_protocol, :http)

    case protocol do
      :http ->
        {:opentelemetry_exporter,
         %{
           endpoints: [
             {:http, endpoint, configure_http_options()}
           ],
           compression: :gzip
         }}

      :grpc ->
        {:opentelemetry_exporter,
         %{
           endpoints: [
             {:grpc, endpoint, configure_grpc_options()}
           ]
         }}
    end
  end

  @doc """
  サンプラーを設定する
  """
  def configure_sampler do
    sampling_ratio = Application.get_env(:opentelemetry, :sampling_ratio, 1.0)

    # 親ベースのサンプラー（分散トレーシングでの一貫性を保つ）
    {:parent_based,
     %{
       # ルートスパンのサンプリング戦略
       root:
         case Application.get_env(:opentelemetry, :sampling_strategy, :ratio) do
           :always_on -> :always_on
           :always_off -> :always_off
           :ratio -> {:trace_id_ratio_based, sampling_ratio}
           :adaptive -> configure_adaptive_sampler()
         end,
       # リモート親がサンプリングされている場合は常にサンプリング
       remote_parent_sampled: :always_on,
       # リモート親がサンプリングされていない場合は常にオフ
       remote_parent_not_sampled: :always_off,
       # ローカル親がサンプリングされている場合は常にサンプリング
       local_parent_sampled: :always_on,
       # ローカル親がサンプリングされていない場合は常にオフ
       local_parent_not_sampled: :always_off
     }}
  end

  @doc """
  アダプティブサンプラーを設定する
  """
  def configure_adaptive_sampler do
    # レート制限付きサンプラー
    {:rate_limiting,
     %{
       # 1秒あたりの最大トレース数
       max_traces_per_second: 100,
       # バーストを許可する時間窓（秒）
       time_window: 1
     }}
  end

  @doc """
  HTTP オプションを設定する
  """
  def configure_http_options do
    [
      # タイムアウト設定
      connect_timeout: 5_000,
      request_timeout: 10_000,
      # リトライ設定
      max_retries: 3,
      retry_delay: 1_000,
      # ヘッダー
      headers: [
        {"Content-Type", "application/x-protobuf"},
        {"User-Agent", "elixir-cqrs-otel/1.0"}
      ]
    ]
  end

  @doc """
  gRPC オプションを設定する
  """
  def configure_grpc_options do
    [
      # 接続プール設定
      pool_size: 5,
      max_connections: 10,
      # Keep-alive設定
      keepalive_time: 30_000,
      keepalive_timeout: 10_000,
      # 圧縮
      compression: :gzip
    ]
  end

  # メールアドレスをマスクする
  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@") do
      [local, domain] ->
        masked_local = String.slice(local, 0, 2) <> "***"
        "#{masked_local}@#{domain}"

      _ ->
        "***@***"
    end
  end

  # 電話番号をマスクする
  defp mask_phone(phone) when is_binary(phone) do
    # 最後の4桁以外をマスク
    case String.length(phone) do
      len when len > 4 ->
        masked = String.duplicate("*", len - 4)
        last_four = String.slice(phone, -4, 4)
        "#{masked}#{last_four}"

      _ ->
        "****"
    end
  end
end
