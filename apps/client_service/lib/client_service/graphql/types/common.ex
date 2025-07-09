defmodule ClientService.GraphQL.Types.Common do
  @moduledoc """
  共通の GraphQL 型定義
  """

  use Absinthe.Schema.Notation

  @desc "ソート順"
  enum :sort_order do
    value :asc, description: "昇順"
    value :desc, description: "降順"
  end

  @desc "削除結果"
  object :delete_result do
    field :success, non_null(:boolean)
    field :message, :string
  end

  @desc "エラー詳細"
  object :error_detail do
    field :field, :string
    field :message, non_null(:string)
  end

  @desc "操作結果"
  interface :result do
    field :success, non_null(:boolean)
    field :errors, list_of(:error_detail)

    resolve_type fn
      %{__typename: type}, _ -> type
      _, _ -> nil
    end
  end
end