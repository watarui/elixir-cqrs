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
  alias Shared.Errors.{AppError, ErrorConverter}

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
      nil -> {:error, AppError.not_found("Product not found", %{id: id})}
      schema -> {:ok, schema_to_entity(schema)}
    end
  end

  @impl true
  def find_by_name(name) when is_binary(name) do
    case Repo.get_by(ProductSchema, name: name) do
      nil -> {:error, AppError.not_found("Product not found", %{name: name})}
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

  @impl true
  def count(conditions \\ %{}) do
    query = from(p in ProductSchema)
    
    query = 
      Enum.reduce(conditions, query, fn
        {:category_id, category_id}, query ->
          where(query, [p], p.category_id == ^category_id)
        {:min_price, min_price}, query ->
          where(query, [p], p.price >= ^min_price)
        {:max_price, max_price}, query ->
          where(query, [p], p.price <= ^max_price)
        _, query ->
          query
      end)
    
    {:ok, Repo.aggregate(query, :count, :id)}
  rescue
    error -> {:error, AppError.infrastructure_error("Failed to count products", %{error: inspect(error)})}
  end

  @impl true
  def transaction(fun) when is_function(fun) do
    Repo.transaction(fun)
  rescue
    error -> {:error, AppError.infrastructure_error("Transaction failed", %{error: inspect(error)})}
  end

  @impl true
  def find_by_price_range(min_price, max_price) do
    schemas = 
      from(p in ProductSchema,
        where: p.price >= ^min_price and p.price <= ^max_price,
        order_by: [asc: p.price]
      )
      |> Repo.all()
    
    entities = Enum.map(schemas, &schema_to_entity/1)
    {:ok, entities}
  rescue
    error -> {:error, AppError.infrastructure_error("Failed to find products by price range", %{error: inspect(error)})}
  end

  @impl true
  def search(keyword) when is_binary(keyword) do
    pattern = "%#{keyword}%"
    
    schemas = 
      from(p in ProductSchema,
        where: ilike(p.name, ^pattern),
        order_by: [asc: p.name]
      )
      |> Repo.all()
    
    entities = Enum.map(schemas, &schema_to_entity/1)
    {:ok, entities}
  rescue
    error -> {:error, AppError.infrastructure_error("Failed to search products", %{error: inspect(error)})}
  end

  @impl true
  def paginate(page, per_page) when page > 0 and per_page > 0 do
    offset = (page - 1) * per_page
    
    query = from(p in ProductSchema, order_by: [desc: p.inserted_at])
    
    total_count = Repo.aggregate(query, :count, :id)
    
    schemas = 
      query
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()
    
    entities = Enum.map(schemas, &schema_to_entity/1)
    {:ok, {entities, total_count}}
  rescue
    error -> {:error, AppError.infrastructure_error("Failed to paginate products", %{error: inspect(error)})}
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
