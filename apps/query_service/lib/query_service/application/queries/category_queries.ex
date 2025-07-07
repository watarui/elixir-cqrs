defmodule QueryService.Application.Queries.CategoryQueries do
  @moduledoc """
  カテゴリ関連のクエリ定義
  """

  alias QueryService.Application.Queries.BaseQuery

  defmodule GetCategory do
    @moduledoc """
    単一カテゴリ取得クエリ
    """
    use BaseQuery

    @enforce_keys [:id]
    defstruct [:id]

    @type t :: %__MODULE__{
            id: String.t()
          }

    @impl true
    def validate(%__MODULE__{} = query) do
      if is_nil(query.id) || query.id == "" do
        {:error, "Category ID is required"}
      else
        :ok
      end
    end

    @impl true
    def metadata(%__MODULE__{}), do: %{query_type: :get_category}
  end

  defmodule ListCategories do
    @moduledoc """
    カテゴリ一覧取得クエリ
    """
    use BaseQuery

    defstruct [:limit, :offset, :sort_by, :sort_order, :include_product_count]

    @type t :: %__MODULE__{
            limit: pos_integer() | nil,
            offset: non_neg_integer() | nil,
            sort_by: atom() | nil,
            sort_order: :asc | :desc | nil,
            include_product_count: boolean() | nil
          }

    @impl true
    def validate(%__MODULE__{} = query) do
      cond do
        not is_nil(query.limit) && query.limit < 1 ->
          {:error, "Limit must be positive"}

        not is_nil(query.offset) && query.offset < 0 ->
          {:error, "Offset must be non-negative"}

        not is_nil(query.sort_order) && query.sort_order not in [:asc, :desc] ->
          {:error, "Sort order must be :asc or :desc"}

        true ->
          :ok
      end
    end

    @impl true
    def metadata(%__MODULE__{}), do: %{query_type: :list_categories}
  end

  defmodule GetCategoryWithProducts do
    @moduledoc """
    カテゴリと関連商品取得クエリ
    """
    use BaseQuery

    @enforce_keys [:id]
    defstruct [:id, :product_limit, :product_offset]

    @type t :: %__MODULE__{
            id: String.t(),
            product_limit: pos_integer() | nil,
            product_offset: non_neg_integer() | nil
          }

    @impl true
    def validate(%__MODULE__{} = query) do
      cond do
        is_nil(query.id) || query.id == "" ->
          {:error, "Category ID is required"}

        not is_nil(query.product_limit) && query.product_limit < 1 ->
          {:error, "Product limit must be positive"}

        not is_nil(query.product_offset) && query.product_offset < 0 ->
          {:error, "Product offset must be non-negative"}

        true ->
          :ok
      end
    end

    @impl true
    def metadata(%__MODULE__{}), do: %{query_type: :get_category_with_products}
  end
end
