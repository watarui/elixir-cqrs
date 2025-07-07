defmodule CommandService.Domain.Entities.Category do
  @moduledoc """
  カテゴリエンティティ

  カテゴリのビジネスルールとドメインロジックを含みます
  """

  alias CommandService.Domain.ValueObjects.{CategoryId, CategoryName}

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :created_at, :updated_at]

  @type t :: %__MODULE__{
          id: CategoryId.t(),
          name: CategoryName.t(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec new(String.t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(id, name) do
    with {:ok, category_id} <- CategoryId.new(id),
         {:ok, category_name} <- CategoryName.new(name) do
      {:ok,
       %__MODULE__{
         id: category_id,
         name: category_name,
         created_at: DateTime.utc_now(),
         updated_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  カテゴリ情報を更新します

  与えられたパラメータマップに基づいて、カテゴリの各フィールドを更新します。
  nilまたは空文字列のフィールドはスキップされます。

  ## パラメータ
    - category: 更新対象のカテゴリエンティティ
    - params: 更新するフィールドを含むマップ
      - :name - カテゴリ名（オプション）

  ## 戻り値
    - {:ok, updated_category} - 更新成功
    - {:error, reason} - バリデーションエラー
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, String.t()}
  def update(%__MODULE__{} = category, params) when is_map(params) do
    update_fields = [
      {:name, params[:name], &update_name/2}
    ]

    Enum.reduce_while(update_fields, {:ok, category}, fn {_field, value, update_fn},
                                                         {:ok, current_category} ->
      case maybe_apply_field_update(current_category, value, update_fn) do
        {:ok, updated_category} -> {:cont, {:ok, updated_category}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  # 個別フィールド更新メソッド（内部使用）
  @spec update_name(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  defp update_name(%__MODULE__{} = category, new_name) do
    case CategoryName.new(new_name) do
      {:ok, name} ->
        {:ok, %__MODULE__{category | name: name, updated_at: DateTime.utc_now()}}

      error ->
        error
    end
  end

  # フィールド更新のヘルパー関数
  @spec maybe_apply_field_update(t(), any(), (t(), any() -> {:ok, t()} | {:error, String.t()})) ::
          {:ok, t()} | {:error, String.t()}
  defp maybe_apply_field_update(category, nil, _update_fn), do: {:ok, category}
  defp maybe_apply_field_update(category, "", _update_fn), do: {:ok, category}
  defp maybe_apply_field_update(category, value, update_fn), do: update_fn.(category, value)

  @spec id(t()) :: String.t()
  def id(%__MODULE__{id: id}), do: CategoryId.value(id)

  @spec name(t()) :: String.t()
  def name(%__MODULE__{name: name}), do: CategoryName.value(name)

  @spec equals?(t(), t()) :: boolean()
  def equals?(%__MODULE__{id: id1}, %__MODULE__{id: id2}) do
    CategoryId.value(id1) == CategoryId.value(id2)
  end
end
