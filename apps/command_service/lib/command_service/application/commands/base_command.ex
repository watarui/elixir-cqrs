defmodule CommandService.Application.Commands.BaseCommand do
  @moduledoc """
  すべてのコマンドの基底モジュール
  
  コマンドの共通的な振る舞いと構造を定義します
  """

  @callback validate(map()) :: {:ok, struct()} | {:error, String.t()}
  @callback command_type() :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour CommandService.Application.Commands.BaseCommand

      @doc """
      コマンドのメタデータを作成する
      """
      def create_metadata(user_id \\ nil, metadata \\ %{}) do
        %{
          command_id: UUID.uuid4(),
          command_type: command_type(),
          user_id: user_id,
          issued_at: DateTime.utc_now(),
          metadata: metadata
        }
      end

      defimpl Jason.Encoder do
        def encode(command, opts) do
          command
          |> Map.from_struct()
          |> Map.reject(fn {_k, v} -> is_nil(v) end)
          |> Jason.Encode.map(opts)
        end
      end
    end
  end
end