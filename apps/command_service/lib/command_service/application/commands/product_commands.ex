defmodule CommandService.Application.Commands.ProductCommands do
  @moduledoc """
  商品関連のコマンド定義
  """

  alias CommandService.Application.Commands.BaseCommand

  defmodule CreateProduct do
    @moduledoc """
    商品作成コマンド
    """
    use BaseCommand

    @enforce_keys [:id, :name, :price, :category_id]
    defstruct [:id, :name, :price, :category_id, :user_id, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            price: String.t() | number() | Decimal.t(),
            category_id: String.t(),
            user_id: String.t() | nil,
            metadata: map() | nil
          }

    def new(params) do
      %__MODULE__{
        id: params[:id] || params[:product_id] || Ecto.UUID.generate(),
        name: params.name,
        price: to_price(params.price),
        category_id: params.category_id,
        user_id: params[:user_id],
        metadata: params[:metadata]
      }
    end

    defp to_price(value) when is_binary(value), do: value
    defp to_price(%Decimal{} = value), do: Decimal.to_string(value)
    defp to_price(value) when is_number(value), do: to_string(value)

    @impl true
    def validate(%__MODULE__{} = cmd) do
      cond do
        is_nil(cmd.id) || cmd.id == "" -> {:error, "Product ID is required"}
        is_nil(cmd.name) || cmd.name == "" -> {:error, "Product name is required"}
        is_nil(cmd.price) -> {:error, "Product price is required"}
        is_nil(cmd.category_id) || cmd.category_id == "" -> {:error, "Category ID is required"}
        true -> :ok
      end
    end

    @impl true
    def aggregate_id(%__MODULE__{id: id}), do: id

    @impl true
    def metadata(%__MODULE__{user_id: user_id, metadata: metadata}) do
      base = %{user_id: user_id, command_type: :create_product}
      if metadata, do: Map.merge(base, metadata), else: base
    end
  end

  defmodule UpdateProduct do
    @moduledoc """
    商品更新コマンド
    """
    use BaseCommand

    @enforce_keys [:id]
    defstruct [
      :id,
      :name,
      :price,
      :category_id,
      :price_change_reason,
      :user_id,
      :updates,
      :metadata
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t() | nil,
            price: String.t() | number() | nil,
            category_id: String.t() | nil,
            price_change_reason: String.t() | nil,
            user_id: String.t() | nil,
            updates: map() | nil,
            metadata: map() | nil
          }

    def new(params) do
      %__MODULE__{
        id: params[:id] || params[:product_id],
        name: params[:name],
        price: if(params[:price], do: to_price(params.price)),
        category_id: params[:category_id],
        price_change_reason: params[:price_change_reason],
        user_id: params[:user_id],
        updates: params[:updates],
        metadata: params[:metadata]
      }
    end

    defp to_price(value) when is_binary(value), do: value
    defp to_price(%Decimal{} = value), do: Decimal.to_string(value)
    defp to_price(value) when is_number(value), do: to_string(value)

    @impl true
    def validate(%__MODULE__{} = cmd) do
      cond do
        is_nil(cmd.id) || cmd.id == "" ->
          {:error, "Product ID is required"}

        is_nil(cmd.name) && is_nil(cmd.price) && is_nil(cmd.category_id) && is_nil(cmd.updates) ->
          {:error, "At least one field must be updated"}

        true ->
          :ok
      end
    end

    @impl true
    def aggregate_id(%__MODULE__{id: id}), do: id

    @impl true
    def metadata(%__MODULE__{user_id: user_id, metadata: metadata}) do
      base = %{user_id: user_id, command_type: :update_product}
      if metadata, do: Map.merge(base, metadata), else: base
    end
  end

  defmodule DeleteProduct do
    @moduledoc """
    商品削除コマンド
    """
    use BaseCommand

    @enforce_keys [:id]
    defstruct [:id, :reason, :user_id, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            reason: String.t() | nil,
            user_id: String.t() | nil,
            metadata: map() | nil
          }

    def new(params) do
      %__MODULE__{
        id: params[:id] || params[:product_id],
        reason: params[:reason],
        user_id: params[:user_id],
        metadata: params[:metadata]
      }
    end

    @impl true
    def validate(%__MODULE__{} = cmd) do
      if is_nil(cmd.id) || cmd.id == "" do
        {:error, "Product ID is required"}
      else
        :ok
      end
    end

    @impl true
    def aggregate_id(%__MODULE__{id: id}), do: id

    @impl true
    def metadata(%__MODULE__{user_id: user_id, metadata: metadata}) do
      base = %{user_id: user_id, command_type: :delete_product}
      if metadata, do: Map.merge(base, metadata), else: base
    end
  end
end
