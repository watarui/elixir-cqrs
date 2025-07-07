defmodule QueryService.Application.Handlers.QueryHandler do
  @moduledoc """
  クエリハンドラーのビヘイビア定義
  """

  @doc """
  クエリを処理する
  """
  @callback handle_query(query :: struct()) :: {:ok, any()} | {:error, term()}

  @doc """
  ハンドラーが処理できるクエリタイプのリストを返す
  """
  @callback query_types() :: list(module())
end
