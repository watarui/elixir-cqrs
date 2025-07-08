defmodule QueryService.Domain.Models.Order do
  @moduledoc """
  Order Model for Query Service

  Represents the read model projection of an order
  """

  defstruct [
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
    :saga_state,
    :created_at,
    :updated_at
  ]

  @type status ::
          :pending | :processing | :confirmed | :shipped | :delivered | :cancelled | :failed

  @type order_item :: %{
          product_id: String.t(),
          product_name: String.t(),
          quantity: non_neg_integer(),
          unit_price: Decimal.t(),
          subtotal: Decimal.t()
        }

  @type shipping_address :: %{
          street: String.t(),
          city: String.t(),
          state: String.t() | nil,
          postal_code: String.t(),
          country: String.t() | nil
        }

  @type saga_state :: %{
          saga_id: String.t(),
          state: String.t(),
          completed_steps: list(String.t()),
          current_step: String.t() | nil,
          error: String.t() | nil,
          started_at: DateTime.t(),
          completed_at: DateTime.t() | nil
        }

  @type t :: %__MODULE__{
          id: String.t(),
          customer_id: String.t(),
          status: status(),
          items: list(order_item()),
          subtotal: Decimal.t(),
          tax_amount: Decimal.t(),
          shipping_cost: Decimal.t(),
          total_amount: Decimal.t(),
          shipping_address: shipping_address() | nil,
          payment_status: String.t() | nil,
          saga_state: saga_state() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new Order model
  """
  @spec new(String.t(), String.t(), status(), list(order_item()), Decimal.t()) :: t()
  def new(id, customer_id, status, items, total_amount) do
    %__MODULE__{
      id: id,
      customer_id: customer_id,
      status: status,
      items: items,
      total_amount: total_amount,
      subtotal: calculate_subtotal(items),
      tax_amount: Decimal.new("0"),
      shipping_cost: Decimal.new("0")
    }
  end

  @doc """
  Creates a new Order model with all fields
  """
  @spec new(map()) :: t()
  def new(params) when is_map(params) do
    %__MODULE__{
      id: params.id,
      customer_id: params.customer_id,
      status: to_atom_status(params.status),
      items: params.items || [],
      subtotal: params.subtotal || Decimal.new("0"),
      tax_amount: params.tax_amount || Decimal.new("0"),
      shipping_cost: params.shipping_cost || Decimal.new("0"),
      total_amount: params.total_amount || Decimal.new("0"),
      shipping_address: params.shipping_address,
      payment_status: params.payment_status,
      saga_state: params.saga_state,
      created_at: params.created_at,
      updated_at: params.updated_at
    }
  end

  @doc """
  Adds shipping address to the order
  """
  @spec with_shipping_address(t(), shipping_address()) :: t()
  def with_shipping_address(%__MODULE__{} = order, shipping_address) do
    %{order | shipping_address: shipping_address}
  end

  @doc """
  Adds pricing details to the order
  """
  @spec with_pricing(t(), Decimal.t(), Decimal.t(), Decimal.t()) :: t()
  def with_pricing(%__MODULE__{} = order, subtotal, tax_amount, shipping_cost) do
    %{
      order
      | subtotal: subtotal,
        tax_amount: tax_amount,
        shipping_cost: shipping_cost
    }
  end

  @doc """
  Adds saga state to the order
  """
  @spec with_saga_state(t(), saga_state()) :: t()
  def with_saga_state(%__MODULE__{} = order, saga_state) do
    %{order | saga_state: saga_state}
  end

  @doc """
  Adds timestamps to the order
  """
  @spec with_timestamps(t(), DateTime.t() | nil, DateTime.t() | nil) :: t()
  def with_timestamps(%__MODULE__{} = order, created_at, updated_at) do
    %{order | created_at: created_at, updated_at: updated_at}
  end

  # Private functions

  defp calculate_subtotal(items) do
    Enum.reduce(items, Decimal.new("0"), fn item, acc ->
      Decimal.add(acc, item.subtotal || Decimal.new("0"))
    end)
  end

  defp to_atom_status(status) when is_atom(status), do: status
  defp to_atom_status("pending"), do: :pending
  defp to_atom_status("processing"), do: :processing
  defp to_atom_status("confirmed"), do: :confirmed
  defp to_atom_status("shipped"), do: :shipped
  defp to_atom_status("delivered"), do: :delivered
  defp to_atom_status("cancelled"), do: :cancelled
  defp to_atom_status("failed"), do: :failed
  defp to_atom_status(_), do: :pending
end
