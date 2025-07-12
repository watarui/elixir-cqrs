defmodule Shared.Telemetry.Tracing.SpanBuilder do
  @moduledoc """
  スパンの構築と属性設定

  OpenTelemetry スパンの作成と属性の標準化を提供します。
  """

  @doc """
  コマンド実行用のスパンを作成する
  """
  def command_span(command, opts \\ []) do
    command_type = command.__struct__ |> Module.split() |> List.last()
    span_name = Keyword.get(opts, :name, "Command.#{command_type}")

    attributes = %{
      "command.type" => command_type,
      "command.module" => inspect(command.__struct__),
      "command.aggregate_id" => get_aggregate_id(command),
      "command.aggregate_type" => get_aggregate_type(command),
      "command.idempotency_key" => get_idempotency_key(command)
    }

    {span_name, build_span_opts(attributes, opts)}
  end

  @doc """
  クエリ実行用のスパンを作成する
  """
  def query_span(query, opts \\ []) do
    query_type = query.__struct__ |> Module.split() |> List.last()
    span_name = Keyword.get(opts, :name, "Query.#{query_type}")

    attributes = %{
      "query.type" => query_type,
      "query.module" => inspect(query.__struct__),
      "query.parameters" => inspect_query_params(query)
    }

    {span_name, build_span_opts(attributes, opts)}
  end

  @doc """
  イベント処理用のスパンを作成する
  """
  def event_span(event, action, opts \\ []) do
    event_type = event.__struct__ |> Module.split() |> List.last()
    span_name = Keyword.get(opts, :name, "Event.#{action}.#{event_type}")

    attributes = %{
      "event.type" => event_type,
      "event.module" => inspect(event.__struct__),
      "event.action" => to_string(action),
      "event.aggregate_id" => get_event_aggregate_id(event),
      "event.aggregate_type" => get_event_aggregate_type(event),
      "event.version" => get_event_version(event)
    }

    {span_name, build_span_opts(attributes, opts)}
  end

  @doc """
  Saga 実行用のスパンを作成する
  """
  def saga_span(saga_id, saga_type, step_name, opts \\ []) do
    span_name = Keyword.get(opts, :name, "Saga.#{saga_type}.#{step_name}")

    attributes = %{
      "saga.id" => saga_id,
      "saga.type" => saga_type,
      "saga.step" => step_name,
      "saga.correlation_id" => Keyword.get(opts, :correlation_id)
    }

    {span_name, build_span_opts(attributes, opts)}
  end

  @doc """
  HTTP リクエスト用のスパンを作成する
  """
  def http_span(method, path, opts \\ []) do
    span_name = Keyword.get(opts, :name, "HTTP #{method} #{path}")

    attributes = %{
      "http.method" => method,
      "http.path" => path,
      "http.url" => Keyword.get(opts, :url),
      "http.target" => Keyword.get(opts, :target),
      "http.host" => Keyword.get(opts, :host),
      "http.scheme" => Keyword.get(opts, :scheme, "http"),
      "http.status_code" => Keyword.get(opts, :status_code),
      "http.user_agent" => Keyword.get(opts, :user_agent)
    }

    {span_name, build_span_opts(attributes, opts, kind: :server)}
  end

  @doc """
  データベース操作用のスパンを作成する
  """
  def db_span(operation, table, opts \\ []) do
    span_name = Keyword.get(opts, :name, "DB #{operation} #{table}")

    attributes = %{
      "db.system" => Keyword.get(opts, :system, "postgresql"),
      "db.operation" => operation,
      "db.table" => table,
      "db.statement" => Keyword.get(opts, :statement),
      "db.rows_affected" => Keyword.get(opts, :rows_affected)
    }

    {span_name, build_span_opts(attributes, opts, kind: :client)}
  end

  @doc """
  外部サービス呼び出し用のスパンを作成する
  """
  def external_service_span(service_name, operation, opts \\ []) do
    span_name = Keyword.get(opts, :name, "External.#{service_name}.#{operation}")

    attributes = %{
      "service.name" => service_name,
      "service.operation" => operation,
      "service.version" => Keyword.get(opts, :service_version),
      "rpc.system" => Keyword.get(opts, :rpc_system),
      "rpc.service" => Keyword.get(opts, :rpc_service),
      "rpc.method" => Keyword.get(opts, :rpc_method)
    }

    {span_name, build_span_opts(attributes, opts, kind: :client)}
  end

  @doc """
  メッセージング操作用のスパンを作成する
  """
  def messaging_span(action, destination, opts \\ []) do
    span_name = Keyword.get(opts, :name, "Messaging.#{action} #{destination}")

    attributes = %{
      "messaging.system" => Keyword.get(opts, :system, "phoenix_pubsub"),
      "messaging.destination" => destination,
      "messaging.destination_kind" => Keyword.get(opts, :destination_kind, "topic"),
      "messaging.operation" => action,
      "messaging.message_id" => Keyword.get(opts, :message_id),
      "messaging.conversation_id" => Keyword.get(opts, :conversation_id)
    }

    kind = if action in ["send", "publish"], do: :producer, else: :consumer
    {span_name, build_span_opts(attributes, opts, kind: kind)}
  end

  @doc """
  カスタムスパンを作成する
  """
  def custom_span(name, attributes, opts \\ []) do
    {name, build_span_opts(attributes, opts)}
  end

  @doc """
  スパンにエラー情報を追加する
  """
  def add_error_to_span(span_ctx, error, stacktrace \\ nil) do
    :otel_span.set_status(span_ctx, :error, format_error(error))

    error_attributes = %{
      "error.type" => error_type(error),
      "error.message" => format_error(error)
    }

    error_attributes =
      if stacktrace do
        Map.put(error_attributes, "error.stacktrace", Exception.format_stacktrace(stacktrace))
      else
        error_attributes
      end

    :otel_span.set_attributes(span_ctx, error_attributes)
  end

  @doc """
  スパンにイベントを追加する
  """
  def add_span_event(span_ctx, name, attributes \\ %{}) do
    timestamp = :opentelemetry.timestamp()
    :otel_span.add_event(span_ctx, name, attributes, timestamp)
  end

  # プライベート関数

  defp build_span_opts(attributes, opts, defaults \\ []) do
    # nil 値を除外
    filtered_attributes =
      attributes
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Enum.into(%{})

    # 追加の属性をマージ
    all_attributes =
      case Keyword.get(opts, :attributes) do
        nil -> filtered_attributes
        extra -> Map.merge(filtered_attributes, extra)
      end

    base_opts = [
      attributes: all_attributes,
      kind: Keyword.get(opts, :kind, Keyword.get(defaults, :kind, :internal))
    ]

    # リンクを追加
    base_opts =
      case Keyword.get(opts, :links) do
        nil -> base_opts
        links -> Keyword.put(base_opts, :links, links)
      end

    # 開始時刻を追加
    case Keyword.get(opts, :start_time) do
      nil -> base_opts
      start_time -> Keyword.put(base_opts, :start_time, start_time)
    end
  end

  defp get_aggregate_id(command) do
    cond do
      Map.has_key?(command, :aggregate_id) -> command.aggregate_id
      Map.has_key?(command, :id) -> command.id
      Map.has_key?(command, :order_id) -> command.order_id
      Map.has_key?(command, :user_id) -> command.user_id
      true -> nil
    end
  end

  defp get_aggregate_type(command) do
    if function_exported?(command.__struct__, :aggregate_type, 0) do
      apply(command.__struct__, :aggregate_type, [])
    else
      nil
    end
  end

  defp get_idempotency_key(command) do
    Map.get(command, :idempotency_key)
  end

  defp get_event_aggregate_id(event) do
    Map.get(event, :aggregate_id)
  end

  defp get_event_aggregate_type(event) do
    Map.get(event, :aggregate_type)
  end

  defp get_event_version(event) do
    Map.get(event, :version)
  end

  defp inspect_query_params(query) do
    query
    |> Map.from_struct()
    |> Enum.reject(fn {k, _} -> k == :__struct__ end)
    |> Enum.into(%{})
    |> inspect()
  end

  defp format_error({:error, reason}) when is_binary(reason), do: reason
  defp format_error({:error, reason}), do: inspect(reason)
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp error_type({:error, %{__struct__: module}}), do: inspect(module)
  defp error_type({:error, reason}) when is_atom(reason), do: to_string(reason)
  defp error_type(_), do: "unknown"
end
