defmodule CommandService.Domain.ValueObjects.ProductId do
  @moduledoc """
  商品IDの値オブジェクト

  IDの型安全性とバリデーションを提供します
  """

  @enforce_keys [:value]
  defstruct [:value]

  @type t :: %__MODULE__{value: String.t()}

  @spec new(String.t()) :: {:ok, t()} | {:error, String.t()}
  def new(value) when is_binary(value) do
    case validate(value) do
      :ok -> {:ok, %__MODULE__{value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, "Invalid product ID type"}

  # プライベート関数 - バリデーション
  defp validate(value) when byte_size(value) > 0, do: :ok
  defp validate(_), do: {:error, "Product ID cannot be empty"}

  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value

  @spec value(t()) :: String.t()
  def value(%__MODULE__{value: value}), do: value
end
