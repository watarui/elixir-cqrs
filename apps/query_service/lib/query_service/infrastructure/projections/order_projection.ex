defmodule QueryService.Infrastructure.Projections.OrderProjection do
  @moduledoc """
  注文プロジェクション

  注文関連のイベントを処理し、Read Model を更新します
  """

  require Logger

  @doc """
  イベントを処理する
  """
  def handle_event(_event) do
    # TODO: 注文関連のイベント処理を実装
    :ok
  end
end
