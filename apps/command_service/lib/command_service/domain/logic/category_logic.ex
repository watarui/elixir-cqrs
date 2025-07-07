defmodule CommandService.Domain.Logic.CategoryLogic do
  @moduledoc """
  カテゴリに関する純粋なビジネスロジック

  副作用を含まない、純粋な関数のみを提供します。
  """

  alias CommandService.Domain.Entities.Category

  @doc """
  カテゴリ名の妥当性を検証

  ## 例
      iex> CategoryLogic.validate_category_name("Electronics")
      :ok

      iex> CategoryLogic.validate_category_name("A")
      {:error, "Category name must be at least 2 characters"}
  """
  @spec validate_category_name(String.t()) :: :ok | {:error, String.t()}
  def validate_category_name(name) when is_binary(name) do
    cond do
      String.length(name) < 2 ->
        {:error, "Category name must be at least 2 characters"}

      String.length(name) > 50 ->
        {:error, "Category name must not exceed 50 characters"}

      not Regex.match?(~r/^[\p{L}\p{N}\s\-_&]+$/u, name) ->
        {:error, "Category name contains invalid characters"}

      true ->
        :ok
    end
  end

  @doc """
  カテゴリ階層の深さを計算

  カテゴリ名からスラッシュ区切りで階層を判定
  """
  @spec calculate_hierarchy_depth(String.t()) :: non_neg_integer()
  def calculate_hierarchy_depth(category_name) when is_binary(category_name) do
    category_name
    |> String.split("/")
    |> length()
  end

  @doc """
  カテゴリのパスを正規化

  ## 例
      iex> CategoryLogic.normalize_category_path("Electronics / Computers / Laptops")
      "Electronics/Computers/Laptops"
  """
  @spec normalize_category_path(String.t()) :: String.t()
  def normalize_category_path(path) when is_binary(path) do
    path
    |> String.split("/")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end

  @doc """
  カテゴリツリーをフラットなリストから構築

  親子関係を持つカテゴリリストからツリー構造を生成
  """
  @spec build_category_tree([%{id: String.t(), name: String.t(), parent_id: String.t() | nil}]) ::
          [%{category: map(), children: list()}]
  def build_category_tree(categories) when is_list(categories) do
    # ルートカテゴリを見つける
    root_categories = Enum.filter(categories, &is_nil(&1.parent_id))

    # 各ルートカテゴリに対して子カテゴリを再帰的に構築
    Enum.map(root_categories, fn root ->
      %{
        category: root,
        children: build_children(root.id, categories)
      }
    end)
  end

  defp build_children(parent_id, all_categories) do
    children = Enum.filter(all_categories, &(&1.parent_id == parent_id))

    Enum.map(children, fn child ->
      %{
        category: child,
        children: build_children(child.id, all_categories)
      }
    end)
  end

  @doc """
  カテゴリの変更を検証
  """
  @spec detect_changes(Category.t(), Category.t()) :: %{
          name_changed: boolean(),
          changes: map()
        }
  def detect_changes(%Category{} = old_category, %Category{} = new_category) do
    name_changed = Category.name(old_category) != Category.name(new_category)

    changes =
      if name_changed do
        %{name: %{from: Category.name(old_category), to: Category.name(new_category)}}
      else
        %{}
      end

    %{
      name_changed: name_changed,
      changes: changes
    }
  end

  @doc """
  カテゴリ名の重複をチェック

  大文字小文字を無視して重複を検出
  """
  @spec has_duplicate_name?([Category.t()], String.t()) :: boolean()
  def has_duplicate_name?(categories, name) when is_list(categories) and is_binary(name) do
    normalized_name = String.downcase(name)

    Enum.any?(categories, fn category ->
      String.downcase(Category.name(category)) == normalized_name
    end)
  end

  @doc """
  カテゴリリストをアルファベット順にソート
  """
  @spec sort_alphabetically([Category.t()]) :: [Category.t()]
  def sort_alphabetically(categories) when is_list(categories) do
    Enum.sort_by(categories, &String.downcase(Category.name(&1)))
  end

  @doc """
  カテゴリ統計情報を計算

  商品数のマップを受け取り、統計を生成
  """
  @spec calculate_statistics([Category.t()], %{String.t() => non_neg_integer()}) :: %{
          total_categories: non_neg_integer(),
          categories_with_products: non_neg_integer(),
          empty_categories: non_neg_integer(),
          average_products_per_category: float()
        }
  def calculate_statistics(categories, product_counts)
      when is_list(categories) and is_map(product_counts) do
    total = length(categories)

    with_products =
      Enum.count(categories, fn category ->
        Map.get(product_counts, Category.id(category), 0) > 0
      end)

    total_products =
      product_counts
      |> Map.values()
      |> Enum.sum()

    %{
      total_categories: total,
      categories_with_products: with_products,
      empty_categories: total - with_products,
      average_products_per_category: if(total > 0, do: total_products / total, else: 0.0)
    }
  end
end
