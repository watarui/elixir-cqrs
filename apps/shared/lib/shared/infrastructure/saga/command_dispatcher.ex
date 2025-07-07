defmodule Shared.Infrastructure.Saga.CommandDispatcher do
  @moduledoc """
  サガからのコマンドをディスパッチするデフォルト実装
  実際のディスパッチは設定されたディスパッチャーに委譲する
  """
  
  @behaviour Shared.Domain.Saga.CommandDispatcherBehaviour
  
  require Logger
  
  @impl true
  def dispatch(command) do
    # この実装はデフォルトのエラーを返す
    # 実際のディスパッチは各アプリケーションで設定する必要がある
    Logger.error("CommandDispatcher not configured. Please configure :command_dispatcher in your application.")
    {:error, :command_dispatcher_not_configured}
  end
  
  @impl true
  def dispatch_parallel(_commands) do
    Logger.error("CommandDispatcher not configured. Please configure :command_dispatcher in your application.")
    {:error, :command_dispatcher_not_configured}
  end
  
  @impl true
  def dispatch_compensation(_command) do
    Logger.error("CommandDispatcher not configured. Please configure :command_dispatcher in your application.")
    {:error, :command_dispatcher_not_configured}
  end
  
end