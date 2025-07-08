defmodule QueryService.Domain.Repositories.OrderRepository do
  @moduledoc """
  Order Repository Behaviour
  """

  alias QueryService.Domain.Models.Order

  @callback find_by_id(String.t()) :: {:ok, Order.t()} | {:error, :not_found}
  @callback find_by_customer_id(String.t()) :: {:ok, list(Order.t())} | {:error, any()}
  @callback list() :: {:ok, list(Order.t())}
  @callback list_by_status(Order.status()) :: {:ok, list(Order.t())}
  @callback list_paginated(map()) :: {:ok, {list(Order.t()), non_neg_integer()}}
  @callback count() :: {:ok, non_neg_integer()}
  @callback count_by_status(Order.status()) :: {:ok, non_neg_integer()}
  @callback exists?(String.t()) :: boolean()
  @callback get_statistics() :: {:ok, map()}
  @callback find_by_date_range(DateTime.t(), DateTime.t()) :: {:ok, list(Order.t())}
end
