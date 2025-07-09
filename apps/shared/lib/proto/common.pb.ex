defmodule ElixirCqrs.Metadata.AdditionalEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule ElixirCqrs.Metadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:request_id, 1, type: :string, json_name: "requestId")
  field(:user_id, 2, type: :string, json_name: "userId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
  field(:additional, 4, repeated: true, type: ElixirCqrs.Metadata.AdditionalEntry, map: true)
end

defmodule ElixirCqrs.Pagination do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:limit, 1, type: :int32)
  field(:offset, 2, type: :int32)
  field(:sort_by, 3, type: :string, json_name: "sortBy")
  field(:sort_order, 4, type: :string, json_name: "sortOrder")
end

defmodule ElixirCqrs.Error.DetailsEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule ElixirCqrs.Error do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:code, 1, type: :string)
  field(:message, 2, type: :string)
  field(:details, 3, repeated: true, type: ElixirCqrs.Error.DetailsEntry, map: true)
end

defmodule ElixirCqrs.Category do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:parent_id, 4, type: :string, json_name: "parentId")
  field(:active, 5, type: :bool)
  field(:product_count, 6, type: :int32, json_name: "productCount")
  field(:created_at, 7, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 8, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
end

defmodule ElixirCqrs.Product do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:category_id, 4, type: :string, json_name: "categoryId")
  field(:category_name, 5, type: :string, json_name: "categoryName")
  field(:price, 6, type: ElixirCqrs.Money)
  field(:stock_quantity, 7, type: :int32, json_name: "stockQuantity")
  field(:active, 8, type: :bool)
  field(:created_at, 9, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 10, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
end

defmodule ElixirCqrs.Money do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:amount, 1, type: :string)
  field(:currency, 2, type: :string)
end

defmodule ElixirCqrs.Order do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:id, 1, type: :string)
  field(:user_id, 2, type: :string, json_name: "userId")
  field(:order_number, 3, type: :string, json_name: "orderNumber")
  field(:status, 4, type: :string)
  field(:total_amount, 5, type: ElixirCqrs.Money, json_name: "totalAmount")
  field(:items, 6, repeated: true, type: ElixirCqrs.OrderItem)
  field(:shipping_address, 7, type: ElixirCqrs.Address, json_name: "shippingAddress")
  field(:payment_method, 8, type: :string, json_name: "paymentMethod")
  field(:payment_status, 9, type: :string, json_name: "paymentStatus")
  field(:shipping_status, 10, type: :string, json_name: "shippingStatus")
  field(:created_at, 11, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 12, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
end

defmodule ElixirCqrs.OrderItem do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:product_id, 1, type: :string, json_name: "productId")
  field(:product_name, 2, type: :string, json_name: "productName")
  field(:quantity, 3, type: :int32)
  field(:unit_price, 4, type: ElixirCqrs.Money, json_name: "unitPrice")
  field(:subtotal, 5, type: ElixirCqrs.Money)
end

defmodule ElixirCqrs.Address do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field(:postal_code, 1, type: :string, json_name: "postalCode")
  field(:prefecture, 2, type: :string)
  field(:city, 3, type: :string)
  field(:address_line1, 4, type: :string, json_name: "addressLine1")
  field(:address_line2, 5, type: :string, json_name: "addressLine2")
  field(:phone_number, 6, type: :string, json_name: "phoneNumber")
end
