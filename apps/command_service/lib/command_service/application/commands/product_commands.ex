defmodule CommandService.Application.Commands.ProductCommands do
  @moduledoc """
  商品に関するコマンド定義
  """

  defmodule CreateProduct do
    @moduledoc """
    商品作成コマンド
    """
    use CommandService.Application.Commands.BaseCommand

    @enforce_keys [:name, :price, :category_id]
    defstruct [:name, :price, :category_id, :metadata]

    @type t :: %__MODULE__{
            name: String.t(),
            price: number(),
            category_id: String.t(),
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, name} <- validate_name(params["name"] || params[:name]),
           {:ok, price} <- validate_price(params["price"] || params[:price]),
           {:ok, category_id} <-
             validate_category_id(params["category_id"] || params[:category_id]) do
        {:ok,
         %__MODULE__{
           name: name,
           price: price,
           category_id: category_id,
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def command_type, do: "product.create"

    defp validate_name(nil), do: {:error, "Name is required"}
    defp validate_name(name) when is_binary(name), do: {:ok, name}
    defp validate_name(_), do: {:error, "Name must be a string"}

    defp validate_price(nil), do: {:error, "Price is required"}
    defp validate_price(price) when is_number(price) and price >= 0, do: {:ok, price}

    defp validate_price(price) when is_binary(price) do
      case Float.parse(price) do
        {value, ""} when value >= 0 -> {:ok, value}
        _ -> {:error, "Invalid price format"}
      end
    end

    defp validate_price(_), do: {:error, "Price must be a non-negative number"}

    defp validate_category_id(nil), do: {:error, "Category ID is required"}
    defp validate_category_id(id) when is_binary(id), do: {:ok, id}
    defp validate_category_id(_), do: {:error, "Category ID must be a string"}
  end

  defmodule UpdateProduct do
    @moduledoc """
    商品更新コマンド
    """
    use CommandService.Application.Commands.BaseCommand

    @enforce_keys [:id]
    defstruct [:id, :name, :price, :category_id, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t() | nil,
            price: number() | nil,
            category_id: String.t() | nil,
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, id} <- validate_id(params["id"] || params[:id]),
           {:ok, updates} <- validate_updates(params) do
        {:ok,
         struct(
           __MODULE__,
           Map.merge(updates, %{id: id, metadata: params["metadata"] || params[:metadata]})
         )}
      end
    end

    @impl true
    def command_type, do: "product.update"

    defp validate_id(nil), do: {:error, "ID is required"}
    defp validate_id(id) when is_binary(id), do: {:ok, id}
    defp validate_id(_), do: {:error, "ID must be a string"}

    defp validate_updates(params) do
      with {:ok, name} <- maybe_validate_field(params, ["name"], &validate_name/1),
           {:ok, price} <- maybe_validate_field(params, ["price"], &validate_price/1),
           {:ok, category_id} <-
             maybe_validate_field(params, ["category_id"], &validate_category_id/1) do
        updates =
          %{}
          |> maybe_put_field(:name, name)
          |> maybe_put_field(:price, price)
          |> maybe_put_field(:category_id, category_id)

        if map_size(updates) == 0 do
          {:error, "At least one field must be updated"}
        else
          {:ok, updates}
        end
      end
    end

    defp maybe_validate_field(params, keys, validator) do
      value = get_nested_value(params, keys)

      if value do
        validator.(value)
      else
        {:ok, nil}
      end
    end

    defp get_nested_value(params, keys) do
      Enum.find_value(keys, fn key ->
        params[key] || params[String.to_atom(key)]
      end)
    end

    defp maybe_put_field(map, _key, nil), do: map
    defp maybe_put_field(map, key, value), do: Map.put(map, key, value)

    defp validate_name(name) when is_binary(name), do: {:ok, name}
    defp validate_name(_), do: {:error, "Name must be a string"}

    defp validate_price(price) when is_number(price) and price >= 0, do: {:ok, price}

    defp validate_price(price) when is_binary(price) do
      case Float.parse(price) do
        {value, ""} when value >= 0 -> {:ok, value}
        _ -> {:error, "Invalid price format"}
      end
    end

    defp validate_price(_), do: {:error, "Price must be a non-negative number"}

    defp validate_category_id(id) when is_binary(id), do: {:ok, id}
    defp validate_category_id(_), do: {:error, "Category ID must be a string"}
  end

  defmodule ChangeProductPrice do
    @moduledoc """
    商品価格変更コマンド
    """
    use CommandService.Application.Commands.BaseCommand

    @enforce_keys [:id, :new_price]
    defstruct [:id, :new_price, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            new_price: number(),
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, id} <- validate_id(params["id"] || params[:id]),
           {:ok, price} <- validate_price(params["new_price"] || params[:new_price]) do
        {:ok,
         %__MODULE__{
           id: id,
           new_price: price,
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def command_type, do: "product.change_price"

    defp validate_id(nil), do: {:error, "ID is required"}
    defp validate_id(id) when is_binary(id), do: {:ok, id}
    defp validate_id(_), do: {:error, "ID must be a string"}

    defp validate_price(nil), do: {:error, "New price is required"}
    defp validate_price(price) when is_number(price) and price >= 0, do: {:ok, price}

    defp validate_price(price) when is_binary(price) do
      case Float.parse(price) do
        {value, ""} when value >= 0 -> {:ok, value}
        _ -> {:error, "Invalid price format"}
      end
    end

    defp validate_price(_), do: {:error, "Price must be a non-negative number"}
  end

  defmodule DeleteProduct do
    @moduledoc """
    商品削除コマンド
    """
    use CommandService.Application.Commands.BaseCommand

    @enforce_keys [:id]
    defstruct [:id, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            metadata: map() | nil
          }

    @impl true
    def validate(params) do
      with {:ok, id} <- validate_id(params["id"] || params[:id]) do
        {:ok,
         %__MODULE__{
           id: id,
           metadata: params["metadata"] || params[:metadata]
         }}
      end
    end

    @impl true
    def command_type, do: "product.delete"

    defp validate_id(nil), do: {:error, "ID is required"}
    defp validate_id(id) when is_binary(id), do: {:ok, id}
    defp validate_id(_), do: {:error, "ID must be a string"}
  end
end
