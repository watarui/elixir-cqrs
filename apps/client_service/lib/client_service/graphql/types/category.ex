defmodule ClientService.GraphQL.Types.Category do
  @moduledoc """
  カテゴリ関連の GraphQL 型定義
  """

  use Absinthe.Schema.Notation

  @desc "カテゴリ"
  object :category do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
    field(:description, :string)
    field(:parent_id, :id)
    field(:active, :boolean)
    field(:product_count, :integer)

    field :products, list_of(:product) do
      resolve(fn _category, _args, _info ->
        # TODO: データローダーで実装
        {:ok, []}
      end)
    end

    field(:created_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
  end

  @desc "カテゴリ作成入力"
  input_object :create_category_input do
    field(:name, non_null(:string))
    field(:description, :string)
    field(:parent_id, :id)
  end

  @desc "カテゴリ更新入力"
  input_object :update_category_input do
    field(:name, :string)
    field(:description, :string)
    field(:parent_id, :id)
  end
end
