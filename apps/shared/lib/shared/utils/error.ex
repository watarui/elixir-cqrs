defmodule ElixirCqrs.Common.Error do
  @moduledoc """
  Error 生成ユーティリティ
  """

  @doc """
  新しいエラーを生成
  """
  def new(code, message) do
    %ElixirCqrs.Error{
      code: code,
      message: message
    }
  end
end
