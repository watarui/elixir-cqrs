defmodule CommandService.Infrastructure.Database.Schemas.CategorySchema do
  @moduledoc """
  カテゴリテーブルのEctoスキーマ

  データベーステーブルとElixir構造体のマッピングを提供します
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "categories" do
    field(:name, :string)

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:id, :name])
    |> validate_required([:id, :name])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:id, name: :categories_pkey)
    |> unique_constraint(:name)
  end
end
