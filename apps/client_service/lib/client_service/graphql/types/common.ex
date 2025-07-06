defmodule ClientService.GraphQL.Types.Common do
  @moduledoc """
  共通GraphQL型定義
  """

  use Absinthe.Schema.Notation

  # 共通のカスタムスカラー型
  scalar :datetime, description: "日時（ISO8601形式）" do
    parse(&parse_datetime/1)
    serialize(&serialize_datetime/1)
  end

  # エラー型定義
  object :error do
    field(:code, non_null(:string), description: "エラーコード")
    field(:message, non_null(:string), description: "エラーメッセージ")
    field(:details, :string, description: "詳細情報")
    field(:field, :string, description: "関連フィールド")
  end

  # 成功・失敗を示すユニオン型
  union :result do
    types([:success, :error])

    resolve_type(fn
      %{success: _}, _ -> :success
      %{error: _}, _ -> :error
      _, _ -> nil
    end)
  end

  # 成功レスポンス
  object :success do
    field(:success, non_null(:boolean), description: "成功フラグ")
    field(:message, :string, description: "成功メッセージ")
    field(:data, :string, description: "追加データ")
  end

  # ページネーション情報
  object :page_info do
    field(:current_page, non_null(:integer), description: "現在のページ")
    field(:per_page, non_null(:integer), description: "ページあたりの件数")
    field(:total_pages, non_null(:integer), description: "総ページ数")
    field(:total_count, non_null(:integer), description: "総件数")
    field(:has_previous_page, non_null(:boolean), description: "前のページがあるか")
    field(:has_next_page, non_null(:boolean), description: "次のページがあるか")
  end

  # ページネーション付きリスト（ジェネリック）
  interface :paginated_list do
    field(:page_info, non_null(:page_info), description: "ページネーション情報")

    resolve_type(fn
      %{categories: _}, _ -> :paginated_categories
      %{products: _}, _ -> :paginated_products
      _, _ -> nil
    end)
  end

  # ページネーション付きカテゴリリスト
  object :paginated_categories do
    interface(:paginated_list)
    field(:page_info, non_null(:page_info), description: "ページネーション情報")
    field(:categories, list_of(:category), description: "カテゴリ一覧")
  end

  # ページネーション付き商品リスト
  object :paginated_products do
    interface(:paginated_list)
    field(:page_info, non_null(:page_info), description: "ページネーション情報")
    field(:products, list_of(:product), description: "商品一覧")
  end

  # 健全性チェック
  object :health_check do
    field(:status, non_null(:string), description: "サービス状態")
    field(:version, non_null(:string), description: "バージョン")
    field(:timestamp, non_null(:datetime), description: "チェック時刻")
    field(:services, list_of(:service_health), description: "依存サービス状態")
  end

  # サービス健全性
  object :service_health do
    field(:name, non_null(:string), description: "サービス名")
    field(:status, non_null(:string), description: "状態")
    field(:response_time, :float, description: "応答時間（ミリ秒）")
    field(:last_checked, :datetime, description: "最終チェック時刻")
  end

  # 統計情報の共通インターフェース
  interface :statistics do
    field(:total_count, non_null(:integer), description: "総件数")
    field(:last_updated, :datetime, description: "最終更新時刻")

    resolve_type(fn
      %{categories_with_timestamps: _}, _ -> :category_statistics
      %{average_price: _}, _ -> :product_statistics
      _, _ -> nil
    end)
  end

  # 検索結果
  object :search_result do
    field(:query, non_null(:string), description: "検索クエリ")
    field(:total_results, non_null(:integer), description: "総検索結果数")
    field(:categories, list_of(:category), description: "カテゴリ検索結果")
    field(:products, list_of(:product), description: "商品検索結果")
    field(:search_time, :float, description: "検索時間（ミリ秒）")
  end

  # 並び順の列挙型
  enum :sort_direction do
    value(:asc, description: "昇順")
    value(:desc, description: "降順")
  end

  # 操作結果
  object :operation_result do
    field(:success, non_null(:boolean), description: "操作成功フラグ")
    field(:message, :string, description: "結果メッセージ")
    field(:affected_count, :integer, description: "影響を受けた件数")
    field(:errors, list_of(:error), description: "エラー一覧")
  end

  # 日時解析関数
  defp parse_datetime(%Absinthe.Blueprint.Input.String{value: value}) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, _} -> :error
    end
  end

  defp parse_datetime(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp parse_datetime(_) do
    :error
  end

  # 日時シリアライズ関数
  defp serialize_datetime(%DateTime{} = datetime) do
    DateTime.to_iso8601(datetime)
  end

  defp serialize_datetime(nil) do
    nil
  end

  defp serialize_datetime(_) do
    nil
  end
end
