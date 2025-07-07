defmodule CommandService.Infrastructure.Repositories.ProductRepository do
  @moduledoc """
  商品リポジトリの実装

  PostgreSQLデータベースを使用した商品の永続化を提供します
  """

  @behaviour CommandService.Domain.Repositories.ProductRepository

  import Ecto.Query, warn: false

  alias CommandService.Domain.Entities.Product
  alias CommandService.Domain.ValueObjects.{ProductId, ProductName, ProductPrice, CategoryId}
  alias CommandService.Infrastructure.Database.{Repo, Schemas.ProductSchema}

  @impl true
  def save(%Product{} = product) do
    attrs = %{
      id: Product.id(product),
      name: Product.name(product),
      price: Product.price(product),
      category_id: Product.category_id(product)
    }

    %ProductSchema{}
    |> ProductSchema.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, schema} -> {:ok, schema_to_entity(schema)}
      {:error, changeset} -> {:error, format_error(changeset)}
    end
  end

  @impl true
  def find_by_id(id) when is_binary(id) do
    case Repo.get(ProductSchema, id) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_entity(schema)}
    end
  end

  @impl true
  def find_by_name(name) when is_binary(name) do
    case Repo.get_by(ProductSchema, name: name) do
      nil -> {:error, :not_found}
      schema -> {:ok, schema_to_entity(schema)}
    end
  end

  @impl true
  def find_by_category_id(category_id) when is_binary(category_id) do
    schemas =
      from(p in ProductSchema, where: p.category_id == ^category_id)
      |> Repo.all()

    entities = Enum.map(schemas, &schema_to_entity/1)
    {:ok, entities}
  end

  @impl true
  def update(%Product{} = product) do
    id = Product.id(product)

    attrs = %{
      name: Product.name(product),
      price: Product.price(product),
      category_id: Product.category_id(product)
    }

    case Repo.get(ProductSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> ProductSchema.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_schema} -> {:ok, schema_to_entity(updated_schema)}
          {:error, changeset} -> {:error, format_error(changeset)}
        end
    end
  end

  @impl true
  def delete(id) when is_binary(id) do
    case Repo.get(ProductSchema, id) do
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
    Repo.exists?(from(p in ProductSchema, where: p.id == ^id))
  end

  @impl true
  def list do
    schemas = Repo.all(ProductSchema)
    entities = Enum.map(schemas, &schema_to_entity/1)
    {:ok, entities}
  end

  # プライベート関数 - スキーマからエンティティへの変換
  defp schema_to_entity(%ProductSchema{} = schema) do
    {:ok, product} = Product.new(schema.id, schema.name, schema.price, schema.category_id)

    %{
      product
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
