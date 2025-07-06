defmodule CommandService.Domain.ValueObjects.CategoryName do
  @moduledoc """
  カテゴリ名の値オブジェクト

  カテゴリ名のバリデーションと不変性を提供します
  """

  @enforce_keys [:value]
  defstruct [:value]

  @type t :: %__MODULE__{value: String.t()}

  @max_length 100
  @min_length 1

  @spec new(String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(value) when is_binary(value) do
    case validate(value) do
      :ok -> {:ok, %__MODULE__{value: String.trim(value)}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, "Invalid category name type"}

  # プライベート関数 - バリデーション
  defp validate(value) do
    trimmed = String.trim(value)

    cond do
      byte_size(trimmed) < @min_length ->
        {:error, "Category name is too short (minimum #{@min_length} characters)"}

      byte_size(trimmed) > @max_length ->
        {:error, "Category name is too long (maximum #{@max_length} characters)"}

      true ->
        :ok
    end
  end

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  @spec value(t()) :: String.t()
  def value(%__MODULE__{value: value}), do: value
end
