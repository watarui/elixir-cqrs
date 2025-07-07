defmodule QueryService.Application.Queries.ProductQueries do
  @moduledoc """
  商品関連のクエリ定義
  """

  alias QueryService.Application.Queries.BaseQuery

  defmodule GetProduct do
    @moduledoc """
    単一商品取得クエリ
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
        {:error, "Product ID is required"}
      else
        :ok
      end
    end

    @impl true
    def metadata(%__MODULE__{}), do: %{query_type: :get_product}
  end

  defmodule ListProducts do
    @moduledoc """
    商品一覧取得クエリ
    """
    use BaseQuery

    defstruct [:category_id, :limit, :offset, :sort_by, :sort_order]

    @type t :: %__MODULE__{
            category_id: String.t() | nil,
            limit: pos_integer() | nil,
            offset: non_neg_integer() | nil,
            sort_by: atom() | nil,
            sort_order: :asc | :desc | nil
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
    def metadata(%__MODULE__{}), do: %{query_type: :list_products}
  end

  defmodule SearchProducts do
    @moduledoc """
    商品検索クエリ
    """
    use BaseQuery

    @enforce_keys [:search_term]
    defstruct [:search_term, :category_id, :min_price, :max_price, :limit, :offset]

    @type t :: %__MODULE__{
            search_term: String.t(),
            category_id: String.t() | nil,
            min_price: Decimal.t() | nil,
            max_price: Decimal.t() | nil,
            limit: pos_integer() | nil,
            offset: non_neg_integer() | nil
          }

    @impl true
    def validate(%__MODULE__{} = query) do
      cond do
        is_nil(query.search_term) || String.trim(query.search_term) == "" ->
          {:error, "Search term is required"}
        
        not is_nil(query.min_price) && not is_nil(query.max_price) && 
          Decimal.compare(query.min_price, query.max_price) == :gt ->
          {:error, "Min price must be less than or equal to max price"}
        
        not is_nil(query.limit) && query.limit < 1 ->
          {:error, "Limit must be positive"}
        
        not is_nil(query.offset) && query.offset < 0 ->
          {:error, "Offset must be non-negative"}
        
        true ->
          :ok
      end
    end

    @impl true
    def metadata(%__MODULE__{}), do: %{query_type: :search_products}
  end

  defmodule GetProductsByCategory do
    @moduledoc """
    カテゴリ別商品取得クエリ
    """
    use BaseQuery

    @enforce_keys [:category_id]
    defstruct [:category_id, :limit, :offset]

    @type t :: %__MODULE__{
            category_id: String.t(),
            limit: pos_integer() | nil,
            offset: non_neg_integer() | nil
          }

    @impl true
    def validate(%__MODULE__{} = query) do
      cond do
        is_nil(query.category_id) || query.category_id == "" ->
          {:error, "Category ID is required"}
        
        not is_nil(query.limit) && query.limit < 1 ->
          {:error, "Limit must be positive"}
        
        not is_nil(query.offset) && query.offset < 0 ->
          {:error, "Offset must be non-negative"}
        
        true ->
          :ok
      end
    end

    @impl true
    def metadata(%__MODULE__{}), do: %{query_type: :get_products_by_category}
  end
end