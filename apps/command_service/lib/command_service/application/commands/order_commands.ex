defmodule CommandService.Application.Commands.OrderCommands do
  @moduledoc """
  注文関連のコマンド定義（サガ用）
  """

  # CreateOrderコマンドの定義
  defmodule CreateOrder do
    @moduledoc """
    注文作成コマンド
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            customer_id: String.t(),
            items: [map()],
            total_amount: Decimal.t() | String.t(),
            shipping_address: map(),
            metadata: map()
          }

    defstruct [:order_id, :customer_id, :items, :total_amount, :shipping_address, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params[:order_id] || params[:id] || Ecto.UUID.generate(),
        customer_id: params.customer_id,
        items: params.items,
        total_amount: to_decimal(params[:total_amount]),
        shipping_address: params.shipping_address,
        metadata: params[:metadata] || %{}
      }
    end

    defp to_decimal(nil), do: nil
    defp to_decimal(value) when is_binary(value), do: Decimal.new(value)
    defp to_decimal(%Decimal{} = value), do: value
    defp to_decimal(value) when is_number(value), do: Decimal.new(to_string(value))
  end

  # 注文更新コマンド
  defmodule UpdateOrder do
    @moduledoc """
    注文更新コマンド
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            status: String.t() | nil,
            shipping_address: map() | nil,
            metadata: map()
          }

    defstruct [:order_id, :status, :shipping_address, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params[:order_id] || params[:id],
        status: params[:status],
        shipping_address: params[:shipping_address],
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 注文キャンセルコマンド
  defmodule CancelOrder do
    @moduledoc """
    注文キャンセルコマンド
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            reason: String.t(),
            metadata: map()
          }

    defstruct [:order_id, :reason, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params[:order_id] || params[:id],
        reason: params[:reason] || "Customer requested cancellation",
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 在庫予約コマンド
  defmodule ReserveInventoryCommand do
    @moduledoc """
    注文商品の在庫を予約するコマンド。
    注文IDと商品リストを指定して在庫を確保する。
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            items: [map()],
            metadata: map()
          }

    defstruct [:order_id, :items, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        items: params.items,
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 在庫解放コマンド
  defmodule ReleaseInventoryCommand do
    @moduledoc """
    予約した在庫を解放するコマンド。
    注文キャンセル時やサガのロールバック時に使用される。
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            items: [map()],
            metadata: map()
          }

    defstruct [:order_id, :items, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        items: params.items,
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 支払い処理コマンド
  defmodule ProcessPaymentCommand do
    @moduledoc """
    注文の支払いを処理するコマンド。
    顧客ID、注文ID、金額を指定して決済を実行する。
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            customer_id: String.t(),
            amount: Decimal.t(),
            metadata: map()
          }

    defstruct [:order_id, :customer_id, :amount, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        customer_id: params.customer_id,
        amount: params.amount,
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 返金コマンド
  defmodule RefundPaymentCommand do
    @moduledoc """
    支払いを返金するコマンド。
    注文キャンセル時やサガのロールバック時に使用される。
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            amount: Decimal.t(),
            metadata: map()
          }

    defstruct [:order_id, :amount, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        amount: params.amount,
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 配送手配コマンド
  defmodule ArrangeShippingCommand do
    @moduledoc """
    注文商品の配送を手配するコマンド。
    配送先住所、商品リストを指定して配送手続きを開始する。
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            shipping_address: map(),
            items: [map()],
            metadata: map()
          }

    defstruct [:order_id, :shipping_address, :items, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        shipping_address: params.shipping_address,
        items: params.items,
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 配送キャンセルコマンド
  defmodule CancelShippingCommand do
    @moduledoc """
    配送手配をキャンセルするコマンド。
    注文キャンセル時やサガのロールバック時に使用される。
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            metadata: map()
          }

    defstruct [:order_id, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 注文確定コマンド
  defmodule ConfirmOrderCommand do
    @moduledoc """
    注文を確定し、完了状態にするコマンド。
    すべてのサガステップが成功した後に実行される。
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            metadata: map()
          }

    defstruct [:order_id, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        metadata: params[:metadata] || %{}
      }
    end
  end

  # 注文キャンセルコマンド
  defmodule CancelOrderCommand do
    @moduledoc """
    注文をキャンセルするコマンド。
    サガのいずれかのステップが失敗した場合に実行される。
    """
    @type t :: %__MODULE__{
            order_id: String.t(),
            metadata: map()
          }

    defstruct [:order_id, :metadata]

    def new(params) do
      %__MODULE__{
        order_id: params.order_id,
        metadata: params[:metadata] || %{}
      }
    end
  end
end
