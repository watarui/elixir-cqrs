defmodule QueryService.Infrastructure.Database.Schemas.ProductSchema do
  @moduledoc """
  Query Service用商品テーブルのEctoスキーマ

  読み取り専用のデータベーステーブルとElixir構造体のマッピングを提供します
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "products" do
    field(:name, :string)
    field(:price, :decimal)

    belongs_to(:category, QueryService.Infrastructure.Database.Schemas.CategorySchema,
      foreign_key: :category_id,
      type: :string
    )

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:id, :name, :price, :category_id])
    |> validate_required([:id, :name, :price, :category_id])
    |> validate_length(:name, min: 1, max: 200)
    |> validate_number(:price, greater_than: 0)
    |> unique_constraint(:id, name: :products_pkey)
    |> foreign_key_constraint(:category_id)
  end
end
