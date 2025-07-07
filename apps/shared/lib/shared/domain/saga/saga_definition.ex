defmodule Shared.Domain.Saga.SagaDefinition do
  @moduledoc """
  Sagaを定義するためのビヘイビア
  """

  @doc """
  Sagaの名前を返す
  """
  @callback name() :: String.t()

  @doc """
  Sagaのステップを定義する
  各ステップは以下の構造を持つ:
  - step: ステップの識別子
  - handler: ステップを実行する関数
  - compensation: 補償処理を実行する関数（オプション）
  """
  @callback steps() :: [
              %{
                step: atom(),
                handler: (map() -> {:ok, map()} | {:error, any()}),
                compensation: (map() -> {:ok, map()}) | nil
              }
            ]

  @doc """
  Sagaモジュールで共通で使用する機能を提供
  """
  defmacro __using__(_) do
    quote do
      @behaviour Shared.Domain.Saga.SagaDefinition

      # コマンドディスパッチャーの設定
      defp get_command_dispatcher do
        Application.get_env(:shared, :command_dispatcher, CommandService.Infrastructure.CommandBus)
      end

      defp dispatch(command) do
        get_command_dispatcher().dispatch(command)
      end

      defp dispatch_parallel(commands) do
        get_command_dispatcher().dispatch_parallel(commands)
      end

      defp dispatch_compensation(command) when is_list(command) do
        Enum.each(command, &dispatch_compensation/1)
      end

      defp dispatch_compensation(command) do
        @command_dispatcher.dispatch_compensation(command)
      end
    end
  end
end
