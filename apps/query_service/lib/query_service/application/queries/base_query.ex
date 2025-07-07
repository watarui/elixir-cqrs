defmodule QueryService.Application.Queries.BaseQuery do
  @moduledoc """
  クエリの基本ビヘイビア
  
  すべてのクエリはこのビヘイビアを実装する必要があります
  """

  @doc """
  クエリのバリデーションを行う
  """
  @callback validate(query :: struct()) :: :ok | {:error, term()}

  @doc """
  クエリのメタデータを返す
  """
  @callback metadata(query :: struct()) :: map()

  defmacro __using__(_opts) do
    quote do
      @behaviour QueryService.Application.Queries.BaseQuery

      @doc """
      クエリを新規作成する
      """
      def new(params) when is_map(params) do
        struct(__MODULE__, params)
      end

      @impl true
      def validate(_query), do: :ok

      @impl true
      def metadata(_query), do: %{}

      defoverridable [validate: 1, metadata: 1]
    end
  end
end