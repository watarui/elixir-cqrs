defmodule Shared.EventLogger do
  @moduledoc """
  簡単なイベントロガー
  将来的な完全なイベントソーシングへの準備
  """

  require Logger

  @doc """
  ビジネスイベントを記録する

  ## 例
      iex> EventLogger.log_event("ProductCreated", %{id: 1, name: "Laptop"})
      :ok
  """
  @spec log_event(String.t(), map()) :: :ok
  def log_event(event_type, data) do
    event = %{
      event_type: event_type,
      data: data,
      timestamp: DateTime.utc_now(),
      service: get_service_name()
    }

    Logger.info("Business event occurred", event)

    # 将来的には EventStore.append(event) に置き換え
    :ok
  end

  @doc """
  ドメインイベントを記録する（構造化）
  """
  @spec log_domain_event(struct()) :: :ok
  def log_domain_event(event_struct) do
    event = %{
      event_type: event_struct.__struct__,
      data: Map.from_struct(event_struct),
      timestamp: DateTime.utc_now(),
      service: get_service_name()
    }

    Logger.info("Domain event occurred", event)
    :ok
  end

  # プライベート関数
  defp get_service_name do
    case Application.get_env(:shared, :service_name) do
      nil -> "unknown_service"
      name -> name
    end
  end
end

# 将来的な完全なイベントソーシング用のイベント構造体
defmodule Shared.Events do
  @moduledoc """
  ドメインイベントの定義
  """

  defmodule ProductCreated do
    defstruct [:id, :name, :price, :category_id, :timestamp]
  end

  defmodule ProductUpdated do
    defstruct [:id, :old_data, :new_data, :timestamp]
  end

  defmodule ProductDeleted do
    defstruct [:id, :timestamp]
  end

  defmodule CategoryCreated do
    defstruct [:id, :name, :timestamp]
  end

  defmodule CategoryUpdated do
    defstruct [:id, :old_name, :new_name, :timestamp]
  end

  defmodule CategoryDeleted do
    defstruct [:id, :timestamp]
  end
end
