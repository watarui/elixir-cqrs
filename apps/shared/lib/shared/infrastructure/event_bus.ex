defmodule Shared.Infrastructure.EventBus do
  @moduledoc """
  イベントバスの実装

  PubSub を使用してイベントの発行と購読を管理します
  """

  # PubSub の名前を定義
  @pubsub_name :event_bus_pubsub

  @doc """
  イベントバスを開始する
  """
  def child_spec(_opts) do
    Phoenix.PubSub.child_spec(name: @pubsub_name)
  end

  @doc """
  イベントを発行する
  """
  @spec publish(atom(), any()) :: :ok
  def publish(event_type, event) do
    Phoenix.PubSub.broadcast(@pubsub_name, "events:#{event_type}", {:event, event})
    Phoenix.PubSub.broadcast(@pubsub_name, "events:all", {:event, event_type, event})
    :ok
  end

  @doc """
  特定のイベントタイプを購読する
  """
  @spec subscribe(atom()) :: :ok | {:error, term()}
  def subscribe(event_type) do
    Phoenix.PubSub.subscribe(@pubsub_name, "events:#{event_type}")
  end

  @doc """
  すべてのイベントを購読する
  """
  @spec subscribe_all() :: :ok | {:error, term()}
  def subscribe_all do
    Phoenix.PubSub.subscribe(@pubsub_name, "events:all")
  end

  @doc """
  購読を解除する
  """
  @spec unsubscribe(atom()) :: :ok
  def unsubscribe(event_type) do
    Phoenix.PubSub.unsubscribe(@pubsub_name, "events:#{event_type}")
  end

  @doc """
  すべてのイベントの購読を解除する
  """
  @spec unsubscribe_all() :: :ok
  def unsubscribe_all do
    Phoenix.PubSub.unsubscribe(@pubsub_name, "events:all")
  end
end
