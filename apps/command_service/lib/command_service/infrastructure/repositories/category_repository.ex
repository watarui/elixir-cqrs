defmodule CommandService.Infrastructure.Repositories.CategoryRepository do
  @moduledoc """
  カテゴリリポジトリの実装

  PostgreSQLデータベースを使用したカテゴリの永続化を提供します
  """

  @behaviour CommandService.Domain.Repositories.CategoryRepository

  import Ecto.Query, warn: false

  alias CommandService.Domain.Entities.Category
  alias CommandService.Infrastructure.Database.{Repo, Schemas.CategorySchema}

  @impl true
  def save(%Category{} = category) do
    attrs = %{
      id: Category.id(category),
      name: Category.name(category)
    }

    %CategorySchema{}
    |> CategorySchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, schema_to_entity(schema)}
      {:error, changeset} -> {:error, format_error(changeset)}
    end
  end

  @impl true
  def find_by_id(id) when is_binary(id) do
    case Repo.get(CategorySchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_entity(schema)}
    end
  end

  @impl true
  def find_by_name(name) when is_binary(name) do
    case Repo.get_by(CategorySchema, name: name) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_entity(schema)}
    end
  end

  @impl true
  def update(%Category{} = category) do
    id = Category.id(category)

    attrs = %{
      name: Category.name(category)
    }

    case Repo.get(CategorySchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> CategorySchema.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_schema} -> {:ok, schema_to_entity(updated_schema)}
          {:error, changeset} -> {:error, format_error(changeset)}
        end
    end
  end

  @impl true
  def delete(id) when is_binary(id) do
    case Repo.get(CategorySchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        case Repo.delete(schema) do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, format_error(changeset)}
        end
    end
  end

  @impl true
  def exists?(id) when is_binary(id) do
    Repo.exists?(from(c in CategorySchema, where: c.id == ^id))
  end

  @impl true
  def list do
    schemas = Repo.all(CategorySchema)
    entities = Enum.map(schemas, &schema_to_entity/1)
    {:ok, entities}
  end

  @impl true
  def has_products?(category_id) when is_binary(category_id) do
    alias CommandService.Infrastructure.Database.Schemas.ProductSchema

    query =
      from(p in ProductSchema,
        where: p.category_id == ^category_id,
        select: count(p.id)
      )

    Repo.one(query) > 0
  end

  # プライベート関数 - スキーマからエンティティへの変換
  defp schema_to_entity(%CategorySchema{} = schema) do
    {:ok, category} = Category.new(schema.id, schema.name)

    %{
      category
      | created_at: to_datetime(schema.inserted_at),
        updated_at: to_datetime(schema.updated_at)
    }
  end

  # タイムスタンプ変換ヘルパー関数
  defp to_datetime(nil), do: nil
  defp to_datetime(%NaiveDateTime{} = naive_dt), do: DateTime.from_naive!(naive_dt, "Etc/UTC")
  defp to_datetime(%DateTime{} = dt), do: dt

  # プライベート関数 - エラーフォーマット
  defp format_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {key, errors} -> "#{key}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
