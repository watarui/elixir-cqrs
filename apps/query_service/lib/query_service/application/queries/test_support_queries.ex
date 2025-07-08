defmodule QueryService.Application.Queries.GetCategoryQuery do
  use QueryService.Application.Queries.BaseQuery
  defstruct [:id, :include_children, :include_parent, :include_product_count]
end

defmodule QueryService.Application.Queries.ListCategoriesQuery do
  use QueryService.Application.Queries.BaseQuery
  defstruct [:level, :parent_id, :include_children, :max_depth, :active_only]
end

defmodule QueryService.Application.Queries.GetCategoryTreeQuery do
  use QueryService.Application.Queries.BaseQuery
  defstruct [:root_id, :max_depth, :include_metadata, :active_only]
end

defmodule QueryService.Application.Queries.GetCategoryPathQuery do
  use QueryService.Application.Queries.BaseQuery
  defstruct [:id, :format]

  @impl true
  def validate(%__MODULE__{id: id}) when is_binary(id), do: :ok
  def validate(_), do: {:error, :invalid_id}
end

defmodule QueryService.Application.Queries.GetProductQuery do
  use QueryService.Application.Queries.BaseQuery
  defstruct [:id, :include_category]

  @impl true
  def validate(%__MODULE__{id: id}) when is_binary(id), do: :ok
  def validate(_), do: {:error, :invalid_id}
end

defmodule QueryService.Application.Queries.ListProductsQuery do
  use QueryService.Application.Queries.BaseQuery

  defstruct page: 1,
            page_size: 20,
            sort_by: "name",
            sort_order: "asc",
            min_price: nil,
            max_price: nil,
            availability: nil

  @impl true
  def validate(query) do
    cond do
      query.page < 1 -> {:error, :invalid_page}
      query.page_size < 1 || query.page_size > 100 -> {:error, :invalid_page_size}
      true -> :ok
    end
  end
end

defmodule QueryService.Application.Queries.SearchProductsQuery do
  use QueryService.Application.Queries.BaseQuery
  defstruct [:search_term, :category_id, :min_price, :max_price, :page, :page_size]

  @impl true
  def validate(%__MODULE__{search_term: term}) when is_binary(term) and term != "", do: :ok
  def validate(_), do: {:error, :search_term_required}
end

defmodule QueryService.Application.Queries.GetProductsByCategoryQuery do
  use QueryService.Application.Queries.BaseQuery
  defstruct [:category_id, :include_subcategories]

  @impl true
  def validate(%__MODULE__{category_id: id}) when is_binary(id), do: :ok
  def validate(_), do: {:error, :invalid_category_id}
end
