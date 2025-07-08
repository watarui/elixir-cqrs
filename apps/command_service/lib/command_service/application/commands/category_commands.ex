defmodule CommandService.Application.Commands.CategoryCommands do
  @moduledoc """
  カテゴリ関連のコマンド定義
  """

  alias CommandService.Application.Commands.BaseCommand

  defmodule CreateCategory do
    @moduledoc """
    カテゴリ作成コマンド
    """
    use BaseCommand

    @enforce_keys [:id, :name]
    defstruct [:id, :name, :description, :parent_id, :user_id, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            description: String.t() | nil,
            parent_id: String.t() | nil,
            user_id: String.t() | nil,
            metadata: map() | nil
          }

    def new(params) do
      %__MODULE__{
        id: params[:id] || params[:category_id] || Ecto.UUID.generate(),
        name: params.name,
        description: params[:description],
        parent_id: params[:parent_id],
        user_id: params[:user_id],
        metadata: params[:metadata]
      }
    end

    @impl true
    def validate(%__MODULE__{} = cmd) do
      cond do
        is_nil(cmd.id) || cmd.id == "" -> {:error, "Category ID is required"}
        is_nil(cmd.name) || cmd.name == "" -> {:error, "Category name is required"}
        true -> :ok
      end
    end

    @impl true
    def aggregate_id(%__MODULE__{id: id}), do: id

    @impl true
    def metadata(%__MODULE__{user_id: user_id, metadata: metadata}) do
      base = %{user_id: user_id, command_type: :create_category}
      if metadata, do: Map.merge(base, metadata), else: base
    end
  end

  defmodule UpdateCategory do
    @moduledoc """
    カテゴリ更新コマンド
    """
    use BaseCommand

    @enforce_keys [:id]
    defstruct [:id, :name, :description, :parent_id, :user_id, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t() | nil,
            description: String.t() | nil,
            parent_id: String.t() | nil,
            user_id: String.t() | nil,
            metadata: map() | nil
          }

    def new(params) do
      %__MODULE__{
        id: params[:id] || params[:category_id],
        name: params[:name],
        description: params[:description],
        parent_id: params[:parent_id],
        user_id: params[:user_id],
        metadata: params[:metadata]
      }
    end

    @impl true
    def validate(%__MODULE__{} = cmd) do
      cond do
        is_nil(cmd.id) || cmd.id == "" ->
          {:error, "Category ID is required"}

        is_nil(cmd.name) && is_nil(cmd.description) && is_nil(cmd.parent_id) ->
          {:error, "At least one field must be updated"}

        true ->
          :ok
      end
    end

    @impl true
    def aggregate_id(%__MODULE__{id: id}), do: id

    @impl true
    def metadata(%__MODULE__{user_id: user_id, metadata: metadata}) do
      base = %{user_id: user_id, command_type: :update_category}
      if metadata, do: Map.merge(base, metadata), else: base
    end
  end

  defmodule DeleteCategory do
    @moduledoc """
    カテゴリ削除コマンド
    """
    use BaseCommand

    @enforce_keys [:id]
    defstruct [:id, :reason, :reassign_products_to, :product_ids, :user_id, :metadata]

    @type t :: %__MODULE__{
            id: String.t(),
            reason: String.t() | nil,
            reassign_products_to: String.t() | nil,
            product_ids: list(String.t()) | nil,
            user_id: String.t() | nil,
            metadata: map() | nil
          }

    def new(params) do
      %__MODULE__{
        id: params[:id] || params[:category_id],
        reason: params[:reason],
        reassign_products_to: params[:reassign_products_to],
        product_ids: params[:product_ids],
        user_id: params[:user_id],
        metadata: params[:metadata]
      }
    end

    @impl true
    def validate(%__MODULE__{} = cmd) do
      cond do
        is_nil(cmd.id) || cmd.id == "" ->
          {:error, "Category ID is required"}

        not is_nil(cmd.reassign_products_to) && (is_nil(cmd.product_ids) || cmd.product_ids == []) ->
          {:error, "Product IDs must be provided when reassigning to another category"}

        true ->
          :ok
      end
    end

    @impl true
    def aggregate_id(%__MODULE__{id: id}), do: id

    @impl true
    def metadata(%__MODULE__{user_id: user_id, metadata: metadata}) do
      base = %{user_id: user_id, command_type: :delete_category}
      if metadata, do: Map.merge(base, metadata), else: base
    end
  end
end
