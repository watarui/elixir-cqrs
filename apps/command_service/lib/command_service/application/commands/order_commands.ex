defmodule CommandService.Application.Commands.OrderCommands do
  @moduledoc """
  注文関連のコマンド定義（サガ用）
  """
  
  # 在庫予約コマンド
  defmodule ReserveInventoryCommand do
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