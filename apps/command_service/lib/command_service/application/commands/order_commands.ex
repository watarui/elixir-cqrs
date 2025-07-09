defmodule CommandService.Application.Commands.OrderCommands do
  @moduledoc """
  注文関連のコマンド定義
  """

  alias CommandService.Application.Commands.BaseCommand

  defmodule CreateOrder do
    @moduledoc """
    注文作成コマンド
    """
    use BaseCommand

    @enforce_keys [:user_id, :items]
    defstruct [:user_id, :items, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.user_id, "user_id"),
           :ok <- validate_items(command.items) do
        {:ok, command}
      end
    end

    defp validate_items(items) when is_list(items) and length(items) > 0 do
      Enum.reduce_while(items, :ok, fn item, acc ->
        case validate_item(item) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end

    defp validate_items(_), do: {:error, "Items must be a non-empty list"}

    defp validate_item(item) do
      with :ok <-
             validate_required(item[:product_id] || item["product_id"], "product_id in item"),
           :ok <-
             validate_positive_integer(item[:quantity] || item["quantity"], "quantity in item"),
           :ok <-
             validate_positive_number(
               item[:unit_price] || item["unit_price"],
               "unit_price in item"
             ) do
        :ok
      end
    end

    defp validate_positive_integer(value, field) when is_integer(value) and value > 0, do: :ok
    defp validate_positive_integer(_, field), do: {:error, "#{field} must be a positive integer"}

    defp validate_positive_number(value, field) when is_number(value) and value > 0, do: :ok
    defp validate_positive_number(_, field), do: {:error, "#{field} must be a positive number"}
  end

  defmodule ConfirmOrder do
    @moduledoc """
    注文確定コマンド
    """
    use BaseCommand

    @enforce_keys [:order_id]
    defstruct [:order_id, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.order_id, "order_id") do
        {:ok, command}
      end
    end
  end

  defmodule CancelOrder do
    @moduledoc """
    注文キャンセルコマンド
    """
    use BaseCommand

    @enforce_keys [:order_id, :reason]
    defstruct [:order_id, :reason, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.order_id, "order_id"),
           :ok <- validate_required(command.reason, "reason") do
        {:ok, command}
      end
    end
  end

  defmodule ReserveInventory do
    @moduledoc """
    在庫予約コマンド
    """
    use BaseCommand

    @enforce_keys [:order_id, :items]
    defstruct [:order_id, :items, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.order_id, "order_id"),
           :ok <- validate_required(command.items, "items") do
        {:ok, command}
      end
    end
  end

  defmodule ProcessPayment do
    @moduledoc """
    支払い処理コマンド
    """
    use BaseCommand

    @enforce_keys [:order_id, :amount]
    defstruct [:order_id, :amount, :payment_id, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.order_id, "order_id"),
           :ok <- validate_required(command.amount, "amount") do
        {:ok, command}
      end
    end
  end

  defmodule ArrangeShipping do
    @moduledoc """
    配送手配コマンド
    """
    use BaseCommand

    @enforce_keys [:order_id, :shipping_address]
    defstruct [:order_id, :shipping_address, :items, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.order_id, "order_id"),
           :ok <- validate_required(command.shipping_address, "shipping_address") do
        {:ok, command}
      end
    end
  end

  # 補償用コマンド

  defmodule ReleaseInventory do
    @moduledoc """
    在庫解放コマンド（補償）
    """
    use BaseCommand

    @enforce_keys [:order_id, :items]
    defstruct [:order_id, :items, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.order_id, "order_id"),
           :ok <- validate_required(command.items, "items") do
        {:ok, command}
      end
    end
  end

  defmodule RefundPayment do
    @moduledoc """
    支払い返金コマンド（補償）
    """
    use BaseCommand

    @enforce_keys [:order_id, :amount]
    defstruct [:order_id, :amount, :payment_id, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.order_id, "order_id"),
           :ok <- validate_required(command.amount, "amount") do
        {:ok, command}
      end
    end
  end

  defmodule CancelShipping do
    @moduledoc """
    配送キャンセルコマンド（補償）
    """
    use BaseCommand

    @enforce_keys [:order_id]
    defstruct [:order_id, :shipping_id, :command_id, :timestamp]

    @impl true
    def new(attrs) do
      struct!(
        __MODULE__,
        Map.merge(attrs, %{
          command_id: UUID.uuid4(),
          timestamp: DateTime.utc_now()
        })
      )
    end

    @impl true
    def validate(%__MODULE__{} = command) do
      with :ok <- validate_required(command.order_id, "order_id") do
        {:ok, command}
      end
    end
  end
end
