defmodule CommandService.Domain.Logic.ProductLogic do
  @moduledoc """
  商品に関する純粋なビジネスロジック

  副作用を含まない、純粋な関数のみを提供します。
  これにより、ビジネスロジックのテストが容易になります。
  """

  alias CommandService.Domain.Entities.Product

  @doc """
  価格が0でないことを検証

  ## 例
      iex> ProductLogic.validate_non_zero_price(100.0)
      :ok

      iex> ProductLogic.validate_non_zero_price(0.0)
      {:error, "Price cannot be zero"}
  """
  @spec validate_non_zero_price(number() | String.t() | Decimal.t()) :: :ok | {:error, String.t()}
  def validate_non_zero_price(price) when is_binary(price) do
    case Decimal.parse(price) do
      {decimal, _} -> validate_non_zero_price(decimal)
      :error -> {:error, "Invalid price format"}
    end
  end

  def validate_non_zero_price(%Decimal{} = price) do
    if Decimal.compare(price, Decimal.new(0)) == :gt do
      :ok
    else
      {:error, "Price cannot be zero or negative"}
    end
  end

  def validate_non_zero_price(price) when is_number(price) do
    if price > 0 do
      :ok
    else
      {:error, "Price cannot be zero or negative"}
    end
  end

  @doc """
  更新パラメータをフィルタリング

  nil、空文字列、および無効な値を除外します。
  """
  @spec filter_update_params(map()) :: map()
  def filter_update_params(params) do
    params
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Enum.into(%{})
  end

  @doc """
  価格更新時のビジネスルールを適用

  - 価格が0の場合は除外
  - 価格が負の場合はエラー
  """
  @spec apply_price_update_rules(map()) :: {:ok, map()} | {:error, String.t()}
  def apply_price_update_rules(params) do
    case params[:price] do
      nil ->
        {:ok, params}

      price ->
        case validate_non_zero_price(price) do
          :ok -> {:ok, params}
          {:error, _} = error -> error
        end
    end
  end

  @doc """
  商品の割引価格を計算（ピュア関数の例）

  ## 例
      iex> product = %Product{price: Decimal.new("100.00")}
      iex> ProductLogic.calculate_discounted_price(product, 10)
      Decimal.new("90.00")
  """
  @spec calculate_discounted_price(Product.t(), number()) :: Decimal.t()
  def calculate_discounted_price(%Product{} = product, discount_percentage)
      when is_number(discount_percentage) and discount_percentage >= 0 and discount_percentage <= 100 do
    price_value = Product.price(product)
    discount_rate = Decimal.div(Decimal.new(discount_percentage), Decimal.new(100))
    discount_amount = Decimal.mult(price_value, discount_rate)
    Decimal.sub(price_value, discount_amount)
  end

  @doc """
  商品情報の変更を検証

  変更前後の商品を比較し、変更内容を返します。
  """
  @spec detect_changes(Product.t(), Product.t()) :: %{
    name_changed: boolean(),
    price_changed: boolean(),
    category_changed: boolean(),
    changes: map()
  }
  def detect_changes(%Product{} = old_product, %Product{} = new_product) do
    name_changed = Product.name(old_product) != Product.name(new_product)
    price_changed = Product.price(old_product) != Product.price(new_product)
    category_changed = Product.category_id(old_product) != Product.category_id(new_product)

    changes = %{}
    |> maybe_add_change(:name, name_changed, Product.name(old_product), Product.name(new_product))
    |> maybe_add_change(:price, price_changed, Product.price(old_product), Product.price(new_product))
    |> maybe_add_change(:category_id, category_changed, Product.category_id(old_product), Product.category_id(new_product))

    %{
      name_changed: name_changed,
      price_changed: price_changed,
      category_changed: category_changed,
      changes: changes
    }
  end

  defp maybe_add_change(changes, _key, false, _old, _new), do: changes
  defp maybe_add_change(changes, key, true, old, new) do
    Map.put(changes, key, %{from: old, to: new})
  end

  @doc """
  商品の価格帯を分類

  ## 例
      iex> ProductLogic.classify_price_range(Decimal.new("50"))
      :budget

      iex> ProductLogic.classify_price_range(Decimal.new("150"))
      :standard
  """
  @spec classify_price_range(Decimal.t()) :: :budget | :standard | :premium | :luxury
  def classify_price_range(%Decimal{} = price) do
    cond do
      Decimal.compare(price, Decimal.new(100)) == :lt -> :budget
      Decimal.compare(price, Decimal.new(500)) == :lt -> :standard
      Decimal.compare(price, Decimal.new(1000)) == :lt -> :premium
      true -> :luxury
    end
  end

  @doc """
  商品リストを価格でソート
  """
  @spec sort_by_price([Product.t()], :asc | :desc) :: [Product.t()]
  def sort_by_price(products, direction \\ :asc) do
    case direction do
      :asc ->
        Enum.sort_by(products, &Product.price/1, fn p1, p2 ->
          Decimal.compare(p1, p2) != :gt
        end)

      :desc ->
        Enum.sort_by(products, &Product.price/1, fn p1, p2 ->
          Decimal.compare(p1, p2) == :gt
        end)
    end
  end

  @doc """
  商品名の妥当性を検証（特殊文字や長さ）
  """
  @spec validate_product_name_format(String.t()) :: :ok | {:error, String.t()}
  def validate_product_name_format(name) when is_binary(name) do
    cond do
      String.length(name) < 2 ->
        {:error, "Product name must be at least 2 characters"}

      String.length(name) > 100 ->
        {:error, "Product name must not exceed 100 characters"}

      not Regex.match?(~r/^[\p{L}\p{N}\s\-_.,()]+$/u, name) ->
        {:error, "Product name contains invalid characters"}

      true ->
        :ok
    end
  end

  @doc """
  複数商品の合計価格を計算
  """
  @spec calculate_total_price([Product.t()]) :: Decimal.t()
  def calculate_total_price(products) when is_list(products) do
    products
    |> Enum.map(&Product.price/1)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end
end
