defmodule ClientService.ErrorJSON do
  @moduledoc """
  エラー用 JSON レスポンス
  """

  @doc """
  エラーを JSON 形式でレンダリングします。
  """
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
