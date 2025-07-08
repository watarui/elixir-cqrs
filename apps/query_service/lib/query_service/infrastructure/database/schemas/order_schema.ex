defmodule QueryService.Infrastructure.Database.Schemas.OrderSchema do
  @moduledoc """
  Order Schema for Query Service Database
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "orders" do
    field(:customer_id, :binary_id)
    field(:status, :string)
    field(:items, {:array, :map})
    field(:subtotal, :decimal)
    field(:tax_amount, :decimal)
    field(:shipping_cost, :decimal)
    field(:total_amount, :decimal)
    field(:shipping_address, :map)
    field(:payment_status, :string)
    field(:saga_state, :map)

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :id,
      :customer_id,
      :status,
      :items,
      :subtotal,
      :tax_amount,
      :shipping_cost,
      :total_amount,
      :shipping_address,
      :payment_status,
      :saga_state
    ])
    |> validate_required([
      :id,
      :customer_id,
      :status,
      :items,
      :total_amount
    ])
    |> validate_inclusion(:status, [
      "pending",
      "processing",
      "confirmed",
      "shipped",
      "delivered",
      "cancelled",
      "failed"
    ])
  end
end
