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
      updates = %{}

      updates =
        if params["name"] || params[:name] do
          case validate_name(params["name"] || params[:name]) do
            {:ok, name} -> Map.put(updates, :name, name)
            error -> error
          end
        else
          updates
        end

      case updates do
        {:error, _} = error ->
          error

        _ ->
          updates =
            if params["price"] || params[:price] do
              case validate_price(params["price"] || params[:price]) do
                {:ok, price} -> Map.put(updates, :price, price)
                error -> error
              end
            else
              updates
            end

          case updates do
            {:error, _} = error ->
              error

            _ ->
              updates =
                if params["category_id"] || params[:category_id] do
                  case validate_category_id(params["category_id"] || params[:category_id]) do
                    {:ok, cat_id} -> Map.put(updates, :category_id, cat_id)
                    error -> error
                  end
                else
                  updates
                end

              case updates do
                {:error, _} = error ->
                  error

                _ ->
                  if map_size(updates) == 0 do
                    {:error, "At least one field must be updated"}
                  else
                    {:ok, updates}
                  end
              end
          end
      end
    end

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
