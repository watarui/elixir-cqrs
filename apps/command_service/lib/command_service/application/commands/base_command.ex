defmodule CommandService.Application.Commands.BaseCommand do
  @moduledoc """
  コマンドの基本ビヘイビア
  
  すべてのコマンドはこのビヘイビアを実装する必要があります
  """

  @doc """
  コマンドのバリデーションを行う
  """
  @callback validate(command :: struct()) :: :ok | {:error, term()}

  @doc """
  コマンドを実行するアグリゲートIDを返す
  """
  @callback aggregate_id(command :: struct()) :: String.t() | nil

  @doc """
  コマンドのメタデータを返す
  """
  @callback metadata(command :: struct()) :: map()

  defmacro __using__(_opts) do
    quote do
      @behaviour CommandService.Application.Commands.BaseCommand

      @doc """
      コマンドを新規作成する
      """
      def new(params) when is_map(params) do
        struct(__MODULE__, params)
      end

      @impl true
      def validate(_command), do: :ok

      @impl true
      def aggregate_id(_command), do: nil

      @impl true
      def metadata(_command), do: %{}

      defoverridable [validate: 1, aggregate_id: 1, metadata: 1]
    end
  end
end