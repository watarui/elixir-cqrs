defmodule Shared.Errors.AppError do
  @moduledoc """
  統一されたアプリケーションエラー構造体
  
  すべてのエラーはこの構造体を使用して表現されます。
  エラーの種類、メッセージ、詳細情報を含みます。
  """
  
  @enforce_keys [:type, :message]
  defstruct [:type, :message, :details, :stacktrace]
  
  @type error_type :: 
    :validation_error |
    :not_found |
    :conflict |
    :unauthorized |
    :forbidden |
    :bad_request |
    :internal_error |
    :service_unavailable |
    :domain_error |
    :infrastructure_error
  
  @type t :: %__MODULE__{
    type: error_type(),
    message: String.t(),
    details: map() | nil,
    stacktrace: list() | nil
  }
  
  @doc """
  新しいエラーを作成します
  
  ## 例
      iex> AppError.new(:validation_error, "Invalid email format")
      %AppError{type: :validation_error, message: "Invalid email format"}
      
      iex> AppError.new(:not_found, "Product not found", %{id: "123"})
      %AppError{type: :not_found, message: "Product not found", details: %{id: "123"}}
  """
  @spec new(error_type(), String.t(), map() | nil) :: t()
  def new(type, message, details \\ nil) do
    %__MODULE__{
      type: type,
      message: message,
      details: details
    }
  end
  
  @doc """
  例外からエラーを作成します
  """
  @spec from_exception(Exception.t(), error_type(), list() | nil) :: t()
  def from_exception(exception, type \\ :internal_error, stacktrace \\ nil) do
    %__MODULE__{
      type: type,
      message: Exception.message(exception),
      stacktrace: stacktrace
    }
  end
  
  @doc """
  バリデーションエラーを作成します
  """
  @spec validation_error(String.t(), map() | nil) :: t()
  def validation_error(message, details \\ nil) do
    new(:validation_error, message, details)
  end
  
  @doc """
  NotFoundエラーを作成します
  """
  @spec not_found(String.t(), map() | nil) :: t()
  def not_found(message, details \\ nil) do
    new(:not_found, message, details)
  end
  
  @doc """
  競合エラーを作成します
  """
  @spec conflict(String.t(), map() | nil) :: t()
  def conflict(message, details \\ nil) do
    new(:conflict, message, details)
  end
  
  @doc """
  ドメインエラーを作成します
  """
  @spec domain_error(String.t(), map() | nil) :: t()
  def domain_error(message, details \\ nil) do
    new(:domain_error, message, details)
  end
  
  @doc """
  インフラストラクチャエラーを作成します
  """
  @spec infrastructure_error(String.t(), map() | nil) :: t()
  def infrastructure_error(message, details \\ nil) do
    new(:infrastructure_error, message, details)
  end
  
  @doc """
  エラーをマップに変換します（JSON/GraphQL応答用）
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = error) do
    base_map = %{
      type: error.type,
      message: error.message
    }
    
    base_map
    |> maybe_add_field(:details, error.details)
    |> maybe_add_field(:stacktrace, format_stacktrace(error.stacktrace))
  end
  
  defp maybe_add_field(map, _key, nil), do: map
  defp maybe_add_field(map, key, value), do: Map.put(map, key, value)
  
  defp format_stacktrace(nil), do: nil
  defp format_stacktrace(stacktrace) when is_list(stacktrace) do
    Enum.map(stacktrace, &Exception.format_stacktrace_entry/1)
  end
  
  @doc """
  エラーをHTTPステータスコードに変換します
  """
  @spec to_http_status(t()) :: pos_integer()
  def to_http_status(%__MODULE__{type: type}) do
    case type do
      :validation_error -> 400
      :bad_request -> 400
      :unauthorized -> 401
      :forbidden -> 403
      :not_found -> 404
      :conflict -> 409
      :internal_error -> 500
      :service_unavailable -> 503
      :domain_error -> 422
      :infrastructure_error -> 500
    end
  end
end