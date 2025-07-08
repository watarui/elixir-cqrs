defmodule Shared.Domain.ValueObjects.Money do
  @moduledoc """
  金額を表す値オブジェクト
  
  日本円（JPY）のみをサポートし、精度の高い金額計算を提供します
  """

  @enforce_keys [:amount, :currency]
  defstruct [:amount, :currency]

  @type t :: %__MODULE__{
    amount: Decimal.t(),
    currency: String.t()
  }

  @doc """
  新しい Money オブジェクトを作成する（日本円のみ）
  
  ## 例
  
      iex> Money.new(1000)
      {:ok, %Money{amount: #Decimal<1000>, currency: "JPY"}}
      
      iex> Money.new(-100)
      {:error, "Amount must be non-negative"}
  """
  @spec new(number()) :: {:ok, t()} | {:error, String.t()}
  def new(amount) when is_number(amount) and amount >= 0 do
    {:ok, %__MODULE__{
      amount: Decimal.new(amount),
      currency: "JPY"
    }}
  end
  def new(amount) when is_number(amount) do
    {:error, "Amount must be non-negative"}
  end
  def new(_), do: {:error, "Invalid amount"}

  @doc """
  文字列から Money オブジェクトを作成する
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_string(amount_str) when is_binary(amount_str) do
    case Decimal.parse(amount_str) do
      {amount, ""} ->
        if Decimal.compare(amount, 0) == :lt do
          {:error, "Amount must be non-negative"}
        else
          {:ok, %__MODULE__{amount: amount, currency: "JPY"}}
        end
      _ ->
        {:error, "Invalid amount format"}
    end
  end

  @doc """
  2つの Money オブジェクトを加算する
  """
  @spec add(t(), t()) :: {:ok, t()} | {:error, String.t()}
  def add(%__MODULE__{currency: c1} = m1, %__MODULE__{currency: c2} = m2) when c1 == c2 do
    {:ok, %__MODULE__{
      amount: Decimal.add(m1.amount, m2.amount),
      currency: c1
    }}
  end
  def add(_, _), do: {:error, "Currency mismatch"}

  @doc """
  Money オブジェクトから別の Money を減算する
  """
  @spec subtract(t(), t()) :: {:ok, t()} | {:error, String.t()}
  def subtract(%__MODULE__{currency: c1} = m1, %__MODULE__{currency: c2} = m2) when c1 == c2 do
    result = Decimal.sub(m1.amount, m2.amount)
    if Decimal.compare(result, 0) == :lt do
      {:error, "Result would be negative"}
    else
      {:ok, %__MODULE__{amount: result, currency: c1}}
    end
  end
  def subtract(_, _), do: {:error, "Currency mismatch"}

  @doc """
  Money オブジェクトに数値を掛ける
  """
  @spec multiply(t(), number()) :: {:ok, t()} | {:error, String.t()}
  def multiply(%__MODULE__{} = money, multiplier) when is_number(multiplier) and multiplier >= 0 do
    {:ok, %__MODULE__{
      amount: Decimal.mult(money.amount, Decimal.new(multiplier)),
      currency: money.currency
    }}
  end
  def multiply(_, _), do: {:error, "Invalid multiplier"}

  @doc """
  2つの Money オブジェクトを比較する
  """
  @spec compare(t(), t()) :: :lt | :eq | :gt | {:error, String.t()}
  def compare(%__MODULE__{currency: c1} = m1, %__MODULE__{currency: c2} = m2) when c1 == c2 do
    Decimal.compare(m1.amount, m2.amount)
  end
  def compare(_, _), do: {:error, "Currency mismatch"}

  @doc """
  Money を整数値（円）として取得する
  """
  @spec to_integer(t()) :: integer()
  def to_integer(%__MODULE__{amount: amount}) do
    amount |> Decimal.round(0) |> Decimal.to_integer()
  end

  @doc """
  Money を文字列として表示する
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{amount: amount, currency: currency}) do
    "#{currency} #{Decimal.to_string(amount)}"
  end

  defimpl String.Chars do
    def to_string(money), do: Shared.Domain.ValueObjects.Money.to_string(money)
  end

  defimpl Jason.Encoder do
    def encode(%{amount: amount, currency: currency}, opts) do
      Jason.Encode.map(%{
        amount: Decimal.to_string(amount),
        currency: currency
      }, opts)
    end
  end
end