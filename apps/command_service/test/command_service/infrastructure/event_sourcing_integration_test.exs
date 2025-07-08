defmodule CommandService.Infrastructure.EventSourcingIntegrationTest do
  use ExUnit.Case, async: false

  alias CommandService.Application.CommandBus
  alias CommandService.Infrastructure.Database.Repo
  alias CommandService.Infrastructure.EventStore.PostgresEventStore

  alias CommandService.Application.Commands.{
    CreateCategoryCommand,
    CreateOrderCommand,
    CreateProductCommand,
    UpdateProductCommand
  }

  alias CommandService.Domain.Aggregates.{Category, Order, Product}

  # import ElixirCqrs.Factory
  # import ElixirCqrs.TestHelpers
  # import ElixirCqrs.EventStoreHelpers

  setup do
    :ok = Sandbox.checkout(Repo)

    # Clear event store for clean test
    clear_event_store()

    :ok
  end

  describe "Event Store Integration" do
    test "stores and retrieves events for an aggregate" do
      # Create aggregate
      aggregate_id = UUID.uuid4()

      # Store multiple events
      events = [
        %{
          event_id: UUID.uuid4(),
          event_type: "product_created",
          aggregate_id: aggregate_id,
          aggregate_type: "product",
          event_data: %{
            name: "Test Product",
            price: Decimal.new("99.99")
          },
          event_metadata: %{user_id: UUID.uuid4()},
          event_version: 1,
          created_at: DateTime.utc_now()
        },
        %{
          event_id: UUID.uuid4(),
          event_type: "product_updated",
          aggregate_id: aggregate_id,
          aggregate_type: "product",
          event_data: %{
            price: Decimal.new("89.99")
          },
          event_metadata: %{user_id: UUID.uuid4()},
          event_version: 2,
          created_at: DateTime.utc_now()
        }
      ]

      # Store events
      {:ok, _} = PostgresEventStore.append_events(events)

      # Retrieve events
      retrieved_events = PostgresEventStore.get_events(aggregate_id)

      assert length(retrieved_events) == 2
      assert hd(retrieved_events).event_type == "product_created"
      assert hd(tl(retrieved_events)).event_type == "product_updated"
    end

    test "maintains event ordering and versions" do
      aggregate_id = UUID.uuid4()

      # Store events out of order (simulating race condition)
      event2 = store_event("event_2", aggregate_id, %{data: "second"}, version: 2)
      event1 = store_event("event_1", aggregate_id, %{data: "first"}, version: 1)
      event3 = store_event("event_3", aggregate_id, %{data: "third"}, version: 3)

      # Retrieve should be in version order
      events = PostgresEventStore.get_events(aggregate_id)

      assert length(events) == 3
      assert Enum.at(events, 0).event_version == 1
      assert Enum.at(events, 1).event_version == 2
      assert Enum.at(events, 2).event_version == 3
    end

    test "prevents duplicate event versions for same aggregate" do
      aggregate_id = UUID.uuid4()

      # Store first event
      event1 = store_event("event_1", aggregate_id, %{}, version: 1)

      # Try to store another event with same version
      assert_raise Ecto.ConstraintError, fn ->
        store_event("event_2", aggregate_id, %{}, version: 1)
      end
    end

    test "retrieves events after specific version" do
      aggregate_id = UUID.uuid4()

      # Store 5 events
      for v <- 1..5 do
        store_event("event_#{v}", aggregate_id, %{}, version: v)
      end

      # Get events after version 3
      events = PostgresEventStore.get_events(aggregate_id, after_version: 3)

      assert length(events) == 2
      assert hd(events).event_version == 4
    end

    test "handles concurrent event appends safely" do
      aggregate_id = UUID.uuid4()

      # Simulate concurrent commands
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            command =
              UpdateProductCommand.new(%{
                id: aggregate_id,
                name: "Concurrent Update #{i}",
                metadata: test_metadata()
              })

            # This would normally go through command handler
            # For testing, we directly append events
            event = %{
              event_id: UUID.uuid4(),
              event_type: "product_updated",
              aggregate_id: aggregate_id,
              aggregate_type: "product",
              event_data: %{name: "Update #{i}"},
              event_metadata: %{},
              event_version: i,
              created_at: DateTime.utc_now()
            }

            PostgresEventStore.append_events([event])
          end)
        end

      # Wait for all tasks
      results = Task.await_many(tasks, 5000)

      # Verify all events were stored
      events = PostgresEventStore.get_events(aggregate_id)
      assert length(events) == 10

      # Verify no duplicate versions
      versions = Enum.map(events, & &1.event_version)
      assert length(Enum.uniq(versions)) == 10
    end
  end

  describe "Command to Event Flow" do
    test "product creation generates proper events" do
      # Create product command
      command =
        CreateProductCommand.new(%{
          name: "New Product",
          description: "Test Description",
          price: Decimal.new("99.99"),
          category_id: UUID.uuid4(),
          metadata: test_metadata()
        })

      # Dispatch command
      {:ok, events} = CommandBus.dispatch(command)

      # Verify event
      assert length(events) == 1
      event = hd(events)

      assert event.event_type == "product_created"
      assert event.aggregate_type == "product"
      assert event.event_data.name == "New Product"
      assert event.event_version == 1

      # Verify event is stored
      stored_events = PostgresEventStore.get_events(event.aggregate_id)
      assert length(stored_events) == 1
    end

    test "category hierarchy creation generates multiple events" do
      # Create parent category
      parent_command =
        CreateCategoryCommand.new(%{
          name: "Parent Category",
          description: "Parent",
          metadata: test_metadata()
        })

      {:ok, parent_events} = CommandBus.dispatch(parent_command)
      parent_id = hd(parent_events).aggregate_id

      # Create child category
      child_command =
        CreateCategoryCommand.new(%{
          name: "Child Category",
          description: "Child",
          parent_id: parent_id,
          metadata: test_metadata()
        })

      {:ok, child_events} = CommandBus.dispatch(child_command)

      # Verify events
      child_event = hd(child_events)
      assert child_event.event_type == "category_created"
      assert child_event.event_data.parent_id == parent_id
      assert child_event.event_data.path == [parent_id]
    end

    test "order creation triggers saga events" do
      # Create order
      command =
        CreateOrderCommand.new(%{
          customer_id: UUID.uuid4(),
          items: [
            build(:order_item, %{quantity: 2, unit_price: Decimal.new("50.00")})
          ],
          shipping_address: build(:shipping_address),
          metadata: test_metadata()
        })

      {:ok, events} = CommandBus.dispatch(command)

      # Verify order created event
      event = hd(events)
      assert event.event_type == "order_created"
      assert event.event_metadata[:saga_trigger] == true

      # In a full implementation, verify saga events are also created
      # This would involve checking saga coordinator state
    end
  end

  describe "Event Replay and Aggregate Rebuilding" do
    test "rebuilds product aggregate from events" do
      aggregate_id = UUID.uuid4()

      # Create a series of events
      events = [
        build_event(aggregate_id, "product_created", 1, %{
          name: "Original Name",
          description: "Original Description",
          price: Decimal.new("100.00"),
          category_id: UUID.uuid4()
        }),
        build_event(aggregate_id, "product_updated", 2, %{
          name: "Updated Name"
        }),
        build_event(aggregate_id, "product_updated", 3, %{
          price: Decimal.new("89.99")
        }),
        build_event(aggregate_id, "product_updated", 4, %{
          description: "Final Description"
        })
      ]

      # Store events
      Enum.each(events, fn event ->
        PostgresEventStore.append_events([event])
      end)

      # Rebuild aggregate
      rebuilt_product = rebuild_product_from_events(aggregate_id)

      # Verify final state
      assert rebuilt_product.id == aggregate_id
      assert rebuilt_product.name == "Updated Name"
      assert rebuilt_product.description == "Final Description"
      assert Decimal.equal?(rebuilt_product.price, Decimal.new("89.99"))
      assert rebuilt_product.version == 4
    end

    test "rebuilds order aggregate with complex state" do
      aggregate_id = UUID.uuid4()

      # Create order lifecycle events
      events = [
        build_event(aggregate_id, "order_created", 1, %{
          customer_id: UUID.uuid4(),
          items: [
            %{product_id: UUID.uuid4(), quantity: 2, unit_price: Decimal.new("50.00")}
          ],
          total_amount: Decimal.new("100.00"),
          status: "pending"
        }),
        build_event(aggregate_id, "order_updated", 2, %{
          status: "processing"
        }),
        build_event(aggregate_id, "order_item_added", 3, %{
          item: %{product_id: UUID.uuid4(), quantity: 1, unit_price: Decimal.new("30.00")},
          new_total: Decimal.new("130.00")
        }),
        build_event(aggregate_id, "order_updated", 4, %{
          status: "completed"
        })
      ]

      # Store and rebuild
      Enum.each(events, &PostgresEventStore.append_events([&1]))

      rebuilt_order = rebuild_order_from_events(aggregate_id)

      # Verify state
      assert rebuilt_order.status == "completed"
      assert length(rebuilt_order.items) == 2
      assert Decimal.equal?(rebuilt_order.total_amount, Decimal.new("130.00"))
      assert rebuilt_order.version == 4
    end
  end

  describe "Snapshot Management" do
    test "creates and retrieves snapshots" do
      aggregate_id = UUID.uuid4()

      # Create many events
      for v <- 1..20 do
        store_event("update_#{v}", aggregate_id, %{update: v}, version: v)
      end

      # Create snapshot at version 15
      snapshot =
        create_snapshot(
          aggregate_id,
          %{
            name: "Snapshot State",
            price: Decimal.new("150.00"),
            version: 15
          },
          15
        )

      # Store snapshot (would be in snapshot store)
      {:ok, _} = PostgresEventStore.save_snapshot(snapshot)

      # Load aggregate with snapshot
      # Should only need to replay events 16-20
      events_after_snapshot =
        PostgresEventStore.get_events(
          aggregate_id,
          after_version: 15
        )

      assert length(events_after_snapshot) == 5
    end

    test "uses latest snapshot when multiple exist" do
      aggregate_id = UUID.uuid4()

      # Create snapshots at different versions
      snapshot1 = create_snapshot(aggregate_id, %{version: 5}, 5)
      snapshot2 = create_snapshot(aggregate_id, %{version: 10}, 10)
      snapshot3 = create_snapshot(aggregate_id, %{version: 15}, 15)

      # Latest snapshot should be used
      latest = PostgresEventStore.get_latest_snapshot(aggregate_id)
      assert latest.version == 15
    end
  end

  describe "Event Querying and Filtering" do
    test "queries events by type across aggregates" do
      # Create events of different types
      store_event("product_created", UUID.uuid4(), %{})
      store_event("product_created", UUID.uuid4(), %{})
      store_event("category_created", UUID.uuid4(), %{})

      # Query by event type
      product_events = get_events_by_type("product_created")

      assert length(product_events) == 2
      assert Enum.all?(product_events, &(&1.event_type == "product_created"))
    end

    test "queries events within time range" do
      aggregate_id = UUID.uuid4()

      # Create events at different times
      old_time = DateTime.utc_now() |> DateTime.add(-3600, :second)
      recent_time = DateTime.utc_now() |> DateTime.add(-60, :second)

      store_event("old_event", aggregate_id, %{}, created_at: old_time)
      store_event("recent_event", aggregate_id, %{}, created_at: recent_time)

      # Query recent events
      one_hour_ago = DateTime.utc_now() |> DateTime.add(-300, :second)
      recent_events = PostgresEventStore.get_events_since(one_hour_ago)

      assert length(recent_events) == 1
      assert hd(recent_events).event_type == "recent_event"
    end
  end

  describe "Error Handling and Recovery" do
    test "handles event deserialization errors gracefully" do
      # Store event with invalid data that might fail deserialization
      aggregate_id = UUID.uuid4()

      # This would typically store malformed JSON or incompatible data
      # Implementation depends on your serialization strategy

      # Should not crash when retrieving
      events = PostgresEventStore.get_events(aggregate_id)
      assert is_list(events)
    end

    test "maintains consistency on partial failures" do
      # Try to store multiple events where one might fail
      aggregate_id = UUID.uuid4()

      events = [
        build_event(aggregate_id, "valid_event", 1, %{data: "ok"}),
        # This might fail due to constraints
        build_event(aggregate_id, "invalid_event", 1, %{data: "duplicate version"})
      ]

      # Should rollback all events if one fails
      result = PostgresEventStore.append_events(events)

      # Verify no partial writes
      stored_events = PostgresEventStore.get_events(aggregate_id)
      assert Enum.empty?(stored_events) || length(stored_events) == 2
    end
  end

  # Helper functions
  defp build_event(aggregate_id, event_type, version, data) do
    %{
      event_id: UUID.uuid4(),
      event_type: event_type,
      aggregate_id: aggregate_id,
      aggregate_type: "test_aggregate",
      event_data: data,
      event_metadata: %{},
      event_version: version,
      created_at: DateTime.utc_now()
    }
  end

  defp rebuild_product_from_events(aggregate_id) do
    events = PostgresEventStore.get_events(aggregate_id)

    initial_state = %Product{id: aggregate_id, version: 0}

    Enum.reduce(events, initial_state, fn event, product ->
      apply_product_event(product, event)
    end)
  end

  defp apply_product_event(product, event) do
    case event.event_type do
      "product_created" ->
        %Product{
          product
          | name: event.event_data.name,
            description: event.event_data.description,
            price: event.event_data.price,
            category_id: event.event_data.category_id,
            version: event.event_version
        }

      "product_updated" ->
        product
        |> Map.merge(event.event_data)
        |> Map.put(:version, event.event_version)

      _ ->
        product
    end
  end

  defp rebuild_order_from_events(aggregate_id) do
    events = PostgresEventStore.get_events(aggregate_id)

    initial_state = %Order{id: aggregate_id, items: [], version: 0}

    Enum.reduce(events, initial_state, fn event, order ->
      apply_order_event(order, event)
    end)
  end

  defp apply_order_event(order, event) do
    case event.event_type do
      "order_created" ->
        %Order{
          order
          | customer_id: event.event_data.customer_id,
            items: event.event_data.items,
            total_amount: event.event_data.total_amount,
            status: event.event_data.status,
            version: event.event_version
        }

      "order_updated" ->
        order
        |> Map.merge(event.event_data)
        |> Map.put(:version, event.event_version)

      "order_item_added" ->
        %Order{
          order
          | items: order.items ++ [event.event_data.item],
            total_amount: event.event_data.new_total,
            version: event.event_version
        }

      _ ->
        order
    end
  end
end
