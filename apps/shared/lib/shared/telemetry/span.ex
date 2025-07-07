defmodule Shared.Telemetry.Span do
  @moduledoc """
  Telemetryメトリクスのためのスパンヘルパー
  （OpenTelemetryの直接使用を避け、Telemetryメトリクスのみを使用）
  """
  
  @doc """
  スパンを開始して、関数を実行し、スパンを終了する
  
  ## 例
      Span.with_span "database.query", %{query: "SELECT * FROM users"} do
        # データベースクエリを実行
      end
  """
  defmacro with_span(name, attributes \\ %{}, do: block) do
    quote do
      span_name = unquote(name)
      span_attrs = unquote(attributes)
      
      # Telemetryイベントを発行
      start_time = System.monotonic_time()
      metadata = Map.put(span_attrs, :span_name, span_name)
      
      :telemetry.execute(
        [:elixir_cqrs, :span, :start],
        %{system_time: System.system_time()},
        metadata
      )
      
      # OpenTelemetryスパンを開始
      try do
        result = unquote(block)
        
        # 成功時のTelemetryイベント
        duration = System.monotonic_time() - start_time
        :telemetry.execute(
          [:elixir_cqrs, :span, :stop],
          %{duration: duration},
          Map.put(metadata, :status, :ok)
        )
        
        result
      rescue
        error ->
          # エラー時のTelemetryイベント
          duration = System.monotonic_time() - start_time
          :telemetry.execute(
            [:elixir_cqrs, :span, :stop],
            %{duration: duration},
            Map.merge(metadata, %{status: :error, error: inspect(error)})
          )
          
          reraise error, __STACKTRACE__
      end
    end
  end
  
  @doc """
  現在のスパンに属性を追加（現在は何もしない）
  """
  def set_attributes(attributes) when is_map(attributes) do
    # OpenTelemetryの直接使用を避けるため、現在は何もしない
    :ok
  end
  
  @doc """
  現在のスパンにイベントを追加（現在は何もしない）
  """
  def add_event(_name, _attributes \\ %{}) do
    # OpenTelemetryの直接使用を避けるため、現在は何もしない
    :ok
  end
  
  @doc """
  現在のスパンのステータスを設定（現在は何もしない）
  """
  def set_status(:ok), do: :ok
  def set_status(:error, _message) do
    # OpenTelemetryの直接使用を避けるため、現在は何もしない
    :ok
  end
end