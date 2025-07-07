defmodule Shared.Domain.Saga.CommandDispatcherBehaviour do
  @moduledoc """
  コマンドディスパッチャーのビヘイビア定義
  サガからコマンドをディスパッチするためのインターフェース
  """

  @callback dispatch(command :: map()) :: {:ok, any()} | {:error, any()}
  @callback dispatch_parallel(commands :: [map()]) :: {:ok, [any()]} | {:error, any()}
  @callback dispatch_compensation(command :: map()) :: {:ok, any()} | {:error, any()}
end
