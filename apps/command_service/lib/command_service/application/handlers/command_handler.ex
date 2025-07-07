defmodule CommandService.Application.Handlers.CommandHandler do
  @moduledoc """
  コマンドハンドラーのビヘイビア定義
  """

  @doc """
  コマンドを処理する
  """
  @callback handle_command(command :: struct()) :: {:ok, any()} | {:error, term()}

  @doc """
  ハンドラーが処理できるコマンドタイプのリストを返す
  """
  @callback command_types() :: list(module())
end