defmodule ElixirCqrs.Factory do
  @moduledoc """
  Test factory for creating test data using ExMachina.
  """
  use ExMachina

  def product_factory do
    %{
      id: UUID.uuid4(),
      name: sequence(:product_name, &"Product #{&1}"),
      description: Faker.Lorem.sentence(),
      price: Faker.Commerce.price() |> Decimal.new(),
      category_id: UUID.uuid4(),
      metadata: %{
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    }
  end

  def category_factory do
    %{
      id: UUID.uuid4(),
      name: sequence(:category_name, &"Category #{&1}"),
      description: Faker.Lorem.sentence(),
      parent_id: nil,
      path: [],
      metadata: %{
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    }
  end

  def order_factory do
    %{
      id: UUID.uuid4(),
      customer_id: UUID.uuid4(),
      items: build_list(3, :order_item),
      total_amount: Decimal.new("100.00"),
      status: "pending",
      shipping_address: build(:shipping_address),
      metadata: %{
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    }
  end

  def order_item_factory do
    %{
      product_id: UUID.uuid4(),
      product_name: Faker.Commerce.product_name(),
      quantity: Enum.random(1..5),
      unit_price: Faker.Commerce.price() |> Decimal.new(),
      subtotal: Decimal.new("50.00")
    }
  end

  def shipping_address_factory do
    %{
      street: Faker.Address.street_address(),
      city: Faker.Address.city(),
      state: Faker.Address.state_abbr(),
      postal_code: Faker.Address.zip_code(),
      country: Faker.Address.country()
    }
  end

  # Command factories
  def create_product_command_factory do
    %{
      type: "create_product",
      payload: build(:product),
      metadata: %{
        user_id: UUID.uuid4(),
        timestamp: DateTime.utc_now()
      }
    }
  end

  def create_category_command_factory do
    %{
      type: "create_category",
      payload: build(:category),
      metadata: %{
        user_id: UUID.uuid4(),
        timestamp: DateTime.utc_now()
      }
    }
  end

  def create_order_command_factory do
    %{
      type: "create_order",
      payload: build(:order),
      metadata: %{
        user_id: UUID.uuid4(),
        timestamp: DateTime.utc_now()
      }
    }
  end

  # Event factories
  def product_created_event_factory do
    %{
      event_id: UUID.uuid4(),
      event_type: "product_created",
      aggregate_id: UUID.uuid4(),
      aggregate_type: "product",
      event_data: build(:product),
      event_metadata: %{
        user_id: UUID.uuid4(),
        timestamp: DateTime.utc_now()
      },
      event_version: 1,
      created_at: DateTime.utc_now()
    }
  end

  def category_created_event_factory do
    %{
      event_id: UUID.uuid4(),
      event_type: "category_created",
      aggregate_id: UUID.uuid4(),
      aggregate_type: "category",
      event_data: build(:category),
      event_metadata: %{
        user_id: UUID.uuid4(),
        timestamp: DateTime.utc_now()
      },
      event_version: 1,
      created_at: DateTime.utc_now()
    }
  end

  def order_created_event_factory do
    %{
      event_id: UUID.uuid4(),
      event_type: "order_created",
      aggregate_id: UUID.uuid4(),
      aggregate_type: "order",
      event_data: build(:order),
      event_metadata: %{
        user_id: UUID.uuid4(),
        timestamp: DateTime.utc_now()
      },
      event_version: 1,
      created_at: DateTime.utc_now()
    }
  end
end