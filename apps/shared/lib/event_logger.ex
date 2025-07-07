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
    @moduledoc """
    商品が作成されたことを表すドメインイベント。
    ID、名称、価格、カテゴリID、タイムスタンプを含む。
    """
    defstruct [:id, :name, :price, :category_id, :timestamp]
  end

  defmodule ProductUpdated do
    @moduledoc """
    商品情報が更新されたことを表すドメインイベント。
    ID、更新前データ、更新後データ、タイムスタンプを含む。
    """
    defstruct [:id, :old_data, :new_data, :timestamp]
  end

  defmodule ProductDeleted do
    @moduledoc """
    商品が削除されたことを表すドメインイベント。
    IDとタイムスタンプを含む。
    """
    defstruct [:id, :timestamp]
  end

  defmodule CategoryCreated do
    @moduledoc """
    カテゴリが作成されたことを表すドメインイベント。
    ID、名称、タイムスタンプを含む。
    """
    defstruct [:id, :name, :timestamp]
  end

  defmodule CategoryUpdated do
    @moduledoc """
    カテゴリ名が更新されたことを表すドメインイベント。
    ID、更新前名称、更新後名称、タイムスタンプを含む。
    """
    defstruct [:id, :old_name, :new_name, :timestamp]
  end

  defmodule CategoryDeleted do
    @moduledoc """
    カテゴリが削除されたことを表すドメインイベント。
    IDとタイムスタンプを含む。
    """
    defstruct [:id, :timestamp]
  end
end
