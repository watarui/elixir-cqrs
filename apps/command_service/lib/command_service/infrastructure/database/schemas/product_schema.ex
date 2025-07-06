defmodule CommandService.Infrastructure.Database.Schemas.ProductSchema do
  @moduledoc """
  商品テーブルのEctoスキーマ

  データベーステーブルとElixir構造体のマッピングを提供します
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias CommandService.Infrastructure.Database.Schemas.CategorySchema

  @primary_key {:id, :string, []}
  schema "products" do
    field(:name, :string)
    field(:price, :decimal)

    belongs_to(:category, CategorySchema, foreign_key: :category_id, type: :string)

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:id, :name, :price, :category_id])
    |> validate_required([:id, :name, :price, :category_id])
    |> validate_length(:name, min: 1, max: 200)
    |> validate_number(:price, greater_than: Decimal.new("0.01"))
    |> unique_constraint(:id, name: :products_pkey)
    |> foreign_key_constraint(:category_id)
  end
end
