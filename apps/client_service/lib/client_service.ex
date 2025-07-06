defmodule ClientService do
  @moduledoc """
  Client Service - GraphQL API とマイクロサービス間通信

  このサービスは以下の責務を持ちます：
  1. GraphQL API の提供
  2. Command Service への gRPC 通信
  3. Query Service への gRPC 通信
  4. リクエストの検証とルーティング
  """

  @doc """
  アプリケーションの現在のバージョンを取得
  """
  def version do
    Application.spec(:client_service, :vsn) |> to_string()
  end

  @doc """
  健全性チェック
  """
  def health_check do
    %{
      status: :ok,
      version: version(),
      timestamp: DateTime.utc_now()
    }
  end
end
