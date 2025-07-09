defmodule QueryService.Domain.ReadModels.Order do
  @moduledoc """
  注文の Read Model
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime]

  schema "orders" do
    field(:user_id, :string)
    field(:total_amount, :decimal)
    field(:currency, :string)
    field(:status, :string)
    field(:items, {:array, :map})

    # 追加フィールド
    field(:payment_id, :string)
    field(:shipping_id, :string)
    field(:cancellation_reason, :string)

    # タイムスタンプ
    field(:confirmed_at, :utc_datetime)
    field(:payment_processed_at, :utc_datetime)
    field(:shipped_at, :utc_datetime)
    field(:delivered_at, :utc_datetime)
    field(:cancelled_at, :utc_datetime)

    timestamps()
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [
      :id,
      :user_id,
      :total_amount,
      :currency,
      :status,
      :items,
      :payment_id,
      :shipping_id,
      :cancellation_reason,
      :confirmed_at,
      :payment_processed_at,
      :shipped_at,
      :delivered_at,
      :cancelled_at
    ])
    |> validate_required([:id, :user_id, :total_amount, :currency, :status])
    |> validate_number(:total_amount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, [
      "pending",
      "confirmed",
      "payment_processed",
      "shipped",
      "delivered",
      "cancelled"
    ])
  end
end
