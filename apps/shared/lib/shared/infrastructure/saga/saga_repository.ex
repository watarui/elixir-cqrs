defmodule Shared.Infrastructure.Saga.SagaRepository do
  @moduledoc """
  SAGA の永続化を管理するリポジトリ

  SAGA の状態を PostgreSQL に保存し、障害時の復旧を可能にします
  """

  alias Shared.Infrastructure.EventStore.Repo
  import Ecto.Query

  require Logger

  @doc """
  SAGA の状態を保存する
  """
  def save_saga(saga_id, saga_state) do
    now = DateTime.utc_now()

    saga_record = %{
      id: saga_id,
      saga_type: saga_state[:saga_type] || "OrderSaga",
      state: Jason.encode!(saga_state),
      current_step: to_string(saga_state[:current_step] || "unknown"),
      status: to_string(saga_state[:state] || "active"),
      created_at: saga_state[:created_at] || now,
      updated_at: now
    }

    case Repo.insert_all(
           "sagas",
           [saga_record],
           on_conflict: {:replace_all_except, [:id, :created_at]},
           conflict_target: :id
         ) do
      {1, _} ->
        Logger.info("Saga #{saga_id} persisted successfully")
        :ok

      error ->
        Logger.error("Failed to persist saga #{saga_id}: #{inspect(error)}")
        {:error, "Failed to persist saga"}
    end
  end

  @doc """
  SAGA の状態を取得する
  """
  def get_saga(saga_id) do
    query = from(s in "sagas", where: s.id == ^saga_id, select: s)

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      saga ->
        {:ok, decode_saga(saga)}
    end
  end

  @doc """
  未完了の SAGA を取得する
  """
  def get_incomplete_sagas do
    query =
      from(s in "sagas",
        where: s.status not in ["completed", "failed", "compensated"],
        select: s
      )

    sagas = Repo.all(query)
    Enum.map(sagas, &decode_saga/1)
  end

  @doc """
  SAGA を削除する
  """
  def delete_saga(saga_id) do
    query = from(s in "sagas", where: s.id == ^saga_id)

    case Repo.delete_all(query) do
      {1, _} -> :ok
      _ -> {:error, :not_found}
    end
  end

  # プライベート関数

  defp decode_saga(saga_record) do
    state = Jason.decode!(saga_record.state, keys: :atoms)

    %{
      saga_id: saga_record.id,
      saga_type: saga_record.saga_type,
      state: state,
      current_step: String.to_atom(saga_record.current_step),
      status: String.to_atom(saga_record.status),
      created_at: saga_record.created_at,
      updated_at: saga_record.updated_at
    }
  end
end
