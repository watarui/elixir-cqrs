defmodule CommandService.Domain.Logic.AggregateLogic do
  @moduledoc """
  アグリゲートに関する純粋なビジネスロジック

  イベントソーシングにおける副作用のない純粋な関数を提供します。
  """

  @doc """
  価格変更が重要な変更かを判定

  ## 例
      iex> AggregateLogic.significant_price_change?("100.00", "110.00", 5)
      true

      iex> AggregateLogic.significant_price_change?("100.00", "101.00", 5)
      false
  """
  @spec significant_price_change?(String.t() | Decimal.t(), String.t() | Decimal.t(), number()) ::
          boolean()
  def significant_price_change?(old_price, new_price, threshold_percent \\ 10) do
    with {:ok, old_decimal} <- to_decimal(old_price),
         {:ok, new_decimal} <- to_decimal(new_price) do
      diff = Decimal.abs(Decimal.sub(new_decimal, old_decimal))

      threshold =
        Decimal.mult(old_decimal, Decimal.div(Decimal.new(threshold_percent), Decimal.new(100)))

      Decimal.compare(diff, threshold) == :gt
    else
      _ -> false
    end
  end

  defp to_decimal(%Decimal{} = d), do: {:ok, d}

  defp to_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> {:ok, decimal}
      :error -> {:error, "Invalid decimal"}
    end
  end

  defp to_decimal(value) when is_number(value), do: {:ok, Decimal.new(value)}

  @doc """
  変更マップから変更内容の説明を生成

  ## 例
      iex> AggregateLogic.describe_changes(%{name: "New Name", price: "200.00"})
      "name, price changed"
  """
  @spec describe_changes(map()) :: String.t()
  def describe_changes(changes) when is_map(changes) do
    changes
    |> Map.keys()
    |> Enum.map(&to_string/1)
    |> Enum.sort()
    |> Enum.join(", ")
    |> case do
      "" -> "no changes"
      desc -> desc <> " changed"
    end
  end

  @doc """
  コマンドが削除済みアグリゲートに対して実行可能かを判定
  """
  @spec command_allowed_on_deleted?(atom()) :: boolean()
  def command_allowed_on_deleted?(command_type) do
    # 削除済みでも実行可能なコマンドのリスト
    allowed_commands = [:restore_product, :view_history]
    command_type in allowed_commands
  end

  @doc """
  イベントの順序が正しいかを検証

  特定のイベントの前後関係を検証します。
  """
  @spec validate_event_sequence([atom()]) :: :ok | {:error, String.t()}
  def validate_event_sequence(event_types) when is_list(event_types) do
    # ProductCreatedは最初に来る必要がある
    case event_types do
      [:product_created | _rest] -> :ok
      [] -> :ok
      _ -> {:error, "ProductCreated event must be first"}
    end
  end

  @doc """
  アグリゲートのバージョンが期待値と一致するかを検証
  """
  @spec validate_expected_version(non_neg_integer(), non_neg_integer() | :any) ::
          :ok | {:error, String.t()}
  def validate_expected_version(_current_version, :any), do: :ok

  def validate_expected_version(current_version, expected_version)
      when current_version == expected_version,
      do: :ok

  def validate_expected_version(current_version, expected_version) do
    {:error, "Version mismatch: expected #{expected_version}, but current is #{current_version}"}
  end

  @doc """
  パラメータから有効な変更のみを抽出

  nil、空文字列、現在値と同じ値を除外します。
  """
  @spec extract_valid_changes(map(), map()) :: map()
  def extract_valid_changes(current_values, new_params) do
    new_params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      current = Map.get(current_values, key)

      cond do
        is_nil(value) -> acc
        value == "" -> acc
        value == current -> acc
        true -> Map.put(acc, key, value)
      end
    end)
  end

  @doc """
  コマンドメタデータを生成

  タイムスタンプやリクエストIDなどを含む標準的なメタデータを生成します。
  """
  @spec build_command_metadata(map()) :: map()
  def build_command_metadata(params \\ %{}) do
    %{
      timestamp: DateTime.utc_now(),
      request_id: Map.get(params, :request_id, generate_request_id()),
      user_id: Map.get(params, :user_id),
      source: Map.get(params, :source, "api")
    }
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
