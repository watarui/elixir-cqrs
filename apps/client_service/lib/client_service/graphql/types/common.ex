defmodule ClientService.GraphQL.Types.Common do
  @moduledoc """
  共通の GraphQL 型定義
  """

  use Absinthe.Schema.Notation

  @desc "JSON 型"
  scalar :json, name: "JSON" do
    serialize(&encode_json/1)
    parse(&decode_json/1)
  end

  defp encode_json(value) when is_binary(value), do: value
  defp encode_json(value), do: value

  defp decode_json(%Absinthe.Blueprint.Input.String{value: value}) do
    case Jason.decode(value) do
      {:ok, result} -> {:ok, result}
      _ -> {:ok, value}
    end
  end

  defp decode_json(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp decode_json(_) do
    :error
  end

  @desc "ソート順"
  enum :sort_order do
    value(:asc, description: "昇順")
    value(:desc, description: "降順")
  end

  @desc "削除結果"
  object :delete_result do
    field(:success, non_null(:boolean))
    field(:message, :string)
  end

  @desc "エラー詳細"
  object :error_detail do
    field(:field, :string)
    field(:message, non_null(:string))
  end

  @desc "操作結果"
  interface :result do
    field(:success, non_null(:boolean))
    field(:errors, list_of(:error_detail))

    resolve_type(fn
      %{__typename: type}, _ -> type
      _, _ -> nil
    end)
  end
end
