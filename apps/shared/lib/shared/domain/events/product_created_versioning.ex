defmodule Shared.Domain.Events.ProductCreated.Versioning do
  @moduledoc """
  ProductCreated イベントのバージョニング実装例

  イベントスキーマの進化を管理する
  """

  use Shared.Infrastructure.EventStore.Versioning.Base

  @impl true
  def current_version, do: 2

  # v1 -> v2: カテゴリIDフィールドを追加
  defp upcast_1_to_2(event) do
    Map.put(event, "category_id", nil)
  end

  # ダウンキャストの実装（v2 -> v1）
  defp downcast_2_to_1(event) do
    Map.delete(event, "category_id")
  end
end
