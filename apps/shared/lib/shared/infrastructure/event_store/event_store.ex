defmodule Shared.Infrastructure.EventStore.EventStore do
  @moduledoc """
  イベントストアのインターフェース
  
  イベントの永続化と取得の抽象化レイヤーを提供します
  """

  @type event :: struct()
  @type aggregate_id :: String.t()
  @type aggregate_type :: String.t()
  @type event_version :: integer()
  @type event_metadata :: map()

  @doc """
  イベントストアの動作を定義するビヘイビア
  """
  @callback append_events(
    aggregate_id(),
    aggregate_type(),
    [event()],
    event_version(),
    event_metadata()
  ) :: {:ok, event_version()} | {:error, term()}

  @callback get_events(
    aggregate_id(),
    from_version :: event_version() | nil
  ) :: {:ok, [event()]} | {:error, term()}

  @callback get_events_by_type(
    event_type :: String.t(),
    opts :: keyword()
  ) :: {:ok, [event()]} | {:error, term()}

  @callback subscribe(
    subscriber :: pid(),
    opts :: keyword()
  ) :: {:ok, subscription :: term()} | {:error, term()}

  @callback unsubscribe(
    subscription :: term()
  ) :: :ok | {:error, term()}

  @doc """
  使用するアダプターを取得する
  """
  def adapter do
    Application.get_env(:shared, :event_store_adapter, Shared.Infrastructure.EventStore.PostgresAdapter)
  end

  @doc """
  イベントを追加する
  """
  def append_events(aggregate_id, aggregate_type, events, expected_version, metadata \\ %{}) do
    adapter().append_events(aggregate_id, aggregate_type, events, expected_version, metadata)
  end

  @doc """
  アグリゲートのイベントを取得する
  """
  def get_events(aggregate_id, from_version \\ nil) do
    adapter().get_events(aggregate_id, from_version)
  end

  @doc """
  特定タイプのイベントを取得する
  """
  def get_events_by_type(event_type, opts \\ []) do
    adapter().get_events_by_type(event_type, opts)
  end

  @doc """
  イベントを購読する
  """
  def subscribe(subscriber, opts \\ []) do
    adapter().subscribe(subscriber, opts)
  end

  @doc """
  購読を解除する
  """
  def unsubscribe(subscription) do
    adapter().unsubscribe(subscription)
  end
end