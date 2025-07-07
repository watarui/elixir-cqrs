defmodule CommandService.Application.Handlers.BaseCommandHandler do
  @moduledoc """
  コマンドハンドラーの基本インターフェース
  """

  @doc """
  ハンドラーが処理できるコマンドタイプのリストを返す
  """
  @callback command_types() :: [module()]

  @doc """
  コマンドを処理する
  """
  @callback handle_command(command :: struct()) :: {:ok, any()} | {:error, term()}

  defmacro __using__(_opts) do
    quote do
      @behaviour CommandService.Application.Handlers.BaseCommandHandler
    end
  end
end