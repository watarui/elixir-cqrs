defmodule CommandService.Infrastructure.Projections.CategoryProjection do
  @moduledoc """
  カテゴリプロジェクション（テスト用のシンプルな実装）

  実際の実装では、イベントハンドラーがイベントを受け取ってプロジェクションを更新します
  """

  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  # カテゴリの追加（テスト用）
  def add_category(category) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, category.id, category)
    end)
  rescue
    _ -> :ok
  end

  # IDで取得
  def get_by_id(id) do
    Agent.get(__MODULE__, fn state ->
      Map.get(state, id)
    end)
  rescue
    _ -> nil
  end

  # 名前と親IDで検索
  def find_by_name_and_parent(name, parent_id) do
    Agent.get(__MODULE__, fn state ->
      Enum.find(Map.values(state), fn category ->
        category.name == name &&
          category.parent_id == parent_id &&
          !category.deleted
      end)
    end)
  rescue
    _ -> nil
  end

  # サブカテゴリの存在チェック
  def has_subcategories?(parent_id) do
    Agent.get(__MODULE__, fn state ->
      Enum.any?(Map.values(state), fn category ->
        category.parent_id == parent_id && !category.deleted
      end)
    end)
  rescue
    _ -> false
  end

  # 子孫チェック
  def descendant_of?(category_id, ancestor_id) do
    category = get_by_id(category_id)

    case category do
      nil ->
        false

      %{parent_id: nil} ->
        false

      %{parent_id: ^ancestor_id} ->
        true

      %{parent_id: parent_id} ->
        is_descendant_of?(parent_id, ancestor_id)
    end
  rescue
    _ -> false
  end

  # テスト用のクリア
  def clear do
    Agent.update(__MODULE__, fn _state -> %{} end)
  rescue
    _ -> :ok
  end
end
