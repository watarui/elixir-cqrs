defmodule Shared.Errors.ErrorConverter do
  @moduledoc """
  様々な形式のエラーをAppError構造体に変換するヘルパーモジュール
  """
  
  alias Shared.Errors.AppError
  
  @doc """
  任意のエラーをAppErrorに変換します
  
  ## 例
      iex> ErrorConverter.to_app_error({:error, "Not found"})
      %AppError{type: :internal_error, message: "Not found"}
      
      iex> ErrorConverter.to_app_error({:error, :not_found})
      %AppError{type: :not_found, message: "Resource not found"}
  """
  @spec to_app_error(any()) :: AppError.t()
  
  # AppErrorはそのまま返す
  def to_app_error(%AppError{} = error), do: error
  
  # {:error, %AppError{}} パターン
  def to_app_error({:error, %AppError{} = error}), do: error
  
  # {:error, message} パターン（文字列）
  def to_app_error({:error, message}) when is_binary(message) do
    AppError.new(:internal_error, message)
  end
  
  # {:error, :atom} パターン
  def to_app_error({:error, :not_found}) do
    AppError.not_found("Resource not found")
  end
  
  def to_app_error({:error, :unauthorized}) do
    AppError.new(:unauthorized, "Unauthorized")
  end
  
  def to_app_error({:error, :forbidden}) do
    AppError.new(:forbidden, "Forbidden")
  end
  
  def to_app_error({:error, atom}) when is_atom(atom) do
    AppError.new(:internal_error, Atom.to_string(atom))
  end
  
  # Ecto.Changeset エラー（Ectoが利用可能な場合のみ）
  def to_app_error({:error, %{__struct__: mod} = changeset}) when mod == Ecto.Changeset do
    if Code.ensure_loaded?(Ecto.Changeset) do
      errors = changeset_errors_to_map(changeset)
      AppError.validation_error("Validation failed", errors)
    else
      AppError.validation_error("Validation failed")
    end
  end
  
  # 例外
  def to_app_error(%{__exception__: true} = exception) do
    AppError.from_exception(exception)
  end
  
  # その他のエラー
  def to_app_error(error) do
    AppError.new(:internal_error, inspect(error))
  end
  
  @doc """
  結果タプルをAppError付きの結果に変換します
  
  ## 例
      iex> ErrorConverter.convert_result({:ok, value})
      {:ok, value}
      
      iex> ErrorConverter.convert_result({:error, "Failed"})
      {:error, %AppError{type: :internal_error, message: "Failed"}}
  """
  @spec convert_result({:ok, any()} | {:error, any()}) :: {:ok, any()} | {:error, AppError.t()}
  def convert_result({:ok, value}), do: {:ok, value}
  def convert_result({:error, error}), do: {:error, to_app_error(error)}
  
  # Ecto.Changesetのエラーをマップに変換
  defp changeset_errors_to_map(changeset) do
    if Code.ensure_loaded?(Ecto.Changeset) do
      apply(Ecto.Changeset, :traverse_errors, [changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end])
    else
      %{}
    end
  end
end