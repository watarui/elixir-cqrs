defmodule Shared.Telemetry.Span do
  @moduledoc """
  OpenTelemetryのスパンを簡単に使用するためのヘルパー
  """
  
  require OpenTelemetry.Tracer, as: Tracer
  
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
      Tracer.with_span span_name, fn ->
        # スパンに属性を設定
        Tracer.set_attributes(span_attrs)
        
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
            
            # OpenTelemetryにエラーを記録
            Tracer.set_status(:error, inspect(error))
            reraise error, __STACKTRACE__
        end
      end
    end
  end
  
  @doc """
  現在のスパンに属性を追加
  """
  def set_attributes(attributes) when is_map(attributes) do
    Tracer.set_attributes(attributes)
  end
  
  @doc """
  現在のスパンにイベントを追加
  """
  def add_event(name, attributes \\ %{}) do
    Tracer.add_event(name, attributes)
  end
  
  @doc """
  現在のスパンのステータスを設定
  """
  def set_status(:ok), do: Tracer.set_status(:ok)
  def set_status(:error, message) do
    Tracer.set_status(:error, message)
  end
end