defmodule QueryService.Infrastructure.Repositories.OrderRepository do
  @moduledoc """
  注文リポジトリの実装（Read Model）

  クエリサービス用の注文データアクセス層
  """

  import Ecto.Query
  alias QueryService.Repo

  # スキーマ定義
  defmodule OrderSchema do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}

    schema "orders" do
      field(:user_id, :binary_id)
      field(:order_number, :string)
      field(:status, :string)
      field(:total_amount, :decimal)
      field(:currency, :string)
      field(:items, {:array, :map}, default: [])
      field(:shipping_address, :map)
      field(:payment_method, :string)
      field(:payment_status, :string)
      field(:shipping_status, :string)
      field(:metadata, :map, default: %{})

      timestamps()
    end
  end

  @doc """
  IDで注文を取得
  """
  def get(id) do
    case Repo.get(OrderSchema, id) do
      nil -> {:error, :not_found}
      order -> {:ok, to_domain_model(order)}
    end
  end

  @doc """
  注文一覧を取得
  """
  def get_all(filters \\ %{}) do
    query =
      OrderSchema
      |> maybe_filter_user(filters[:user_id])
      |> maybe_filter_status(filters[:status])
      |> maybe_sort(filters[:sort_by], filters[:sort_order])
      |> maybe_limit(filters[:limit])
      |> maybe_offset(filters[:offset])

    orders = Repo.all(query)
    {:ok, Enum.map(orders, &to_domain_model/1)}
  end

  @doc """
  注文を検索
  """
  def search(filters) do
    query = OrderSchema

    query =
      query
      |> maybe_filter_user(filters[:user_id])
      |> maybe_filter_status(filters[:status])
      |> maybe_filter_date_range(filters[:from_date], filters[:to_date])
      |> maybe_filter_amount_range(filters[:min_amount], filters[:max_amount])
      |> maybe_sort(filters[:sort_by], filters[:sort_order])
      |> maybe_limit(filters[:limit])
      |> maybe_offset(filters[:offset])

    orders = Repo.all(query)
    {:ok, Enum.map(orders, &to_domain_model/1)}
  end

  # Private functions

  defp to_domain_model(schema) do
    %{
      id: schema.id,
      user_id: schema.user_id,
      order_number: schema.order_number,
      status: schema.status,
      total_amount: schema.total_amount,
      currency: schema.currency,
      items: schema.items,
      shipping_address: schema.shipping_address,
      payment_method: schema.payment_method,
      payment_status: schema.payment_status,
      shipping_status: schema.shipping_status,
      created_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp maybe_filter_user(query, nil), do: query

  defp maybe_filter_user(query, user_id) do
    from(o in query, where: o.user_id == ^user_id)
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    from(o in query, where: o.status == ^status)
  end

  defp maybe_filter_date_range(query, nil, nil), do: query

  defp maybe_filter_date_range(query, from_date, nil) do
    from(o in query, where: o.inserted_at >= ^from_date)
  end

  defp maybe_filter_date_range(query, nil, to_date) do
    from(o in query, where: o.inserted_at <= ^to_date)
  end

  defp maybe_filter_date_range(query, from_date, to_date) do
    from(o in query,
      where: o.inserted_at >= ^from_date,
      where: o.inserted_at <= ^to_date
    )
  end

  defp maybe_filter_amount_range(query, nil, nil), do: query

  defp maybe_filter_amount_range(query, min_amount, nil) do
    from(o in query, where: o.total_amount >= ^min_amount)
  end

  defp maybe_filter_amount_range(query, nil, max_amount) do
    from(o in query, where: o.total_amount <= ^max_amount)
  end

  defp maybe_filter_amount_range(query, min_amount, max_amount) do
    from(o in query,
      where: o.total_amount >= ^min_amount,
      where: o.total_amount <= ^max_amount
    )
  end

  defp maybe_sort(query, nil, _), do: from(o in query, order_by: [desc: o.inserted_at])

  defp maybe_sort(query, field, order) do
    order = order || :desc
    from(o in query, order_by: [{^order, ^String.to_atom(field)}])
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: from(o in query, limit: ^limit)

  defp maybe_offset(query, nil), do: query
  defp maybe_offset(query, offset), do: from(o in query, offset: ^offset)
end
