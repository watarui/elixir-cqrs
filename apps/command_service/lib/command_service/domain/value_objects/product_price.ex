defmodule CommandService.Domain.ValueObjects.ProductPrice do
  @moduledoc """
  商品価格の値オブジェクト

  価格の型安全性とバリデーションを提供します
  """

  @enforce_keys [:value]
  defstruct [:value]

  @opaque t :: %__MODULE__{value: Decimal.t()}

  @min_price Decimal.new("0.01")
  @max_price Decimal.new("999999.99")

  @spec new(Decimal.t() | String.t() | number()) :: {:ok, t()} | {:error, String.t()}
  def new(value) when is_integer(value) do
    value |> to_string() |> Decimal.new() |> new()
  end

  def new(value) when is_float(value) do
    value |> to_string() |> Decimal.new() |> new()
  end

  def new(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> new(decimal)
      _ -> {:error, "Invalid price format"}
    end
  end

  def new(%Decimal{} = value) do
    case validate(value) do
      :ok -> {:ok, %__MODULE__{value: value}}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(_), do: {:error, "Invalid price type"}

  # プライベート関数 - バリデーション
  defp validate(value) do
    cond do
      Decimal.compare(value, @min_price) == :lt ->
        {:error, "Price must be greater than or equal to #{Decimal.to_string(@min_price)}"}

      Decimal.compare(value, @max_price) == :gt ->
        {:error, "Price must be less than or equal to #{Decimal.to_string(@max_price)}"}

      true ->
        :ok
    end
  end

  @spec to_string_value(t()) :: String.t()
  def to_string_value(%__MODULE__{value: value}), do: Decimal.to_string(value)

  @spec value(t()) :: Decimal.t()
  def value(%__MODULE__{value: value}), do: value

  @spec to_float(t()) :: float()
  def to_float(%__MODULE__{value: value}), do: Decimal.to_float(value)
end
