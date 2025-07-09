#!/bin/bash

echo "=== Simple Event Sourcing Test ==="

# Test 1: Create category via GraphQL
echo -e "\n1. Creating category..."
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "mutation { createCategory(input: { name: \"Test\", description: \"Test Desc\" }) { id name } }"}'

# Test 2: Query categories
echo -e "\n\n2. Querying categories..."
curl -X POST http://localhost:4000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "query { categories { id name description productCount } }"}'

# Test 3: Check events in database
echo -e "\n\n3. Checking events in database..."
docker exec elixir-cqrs-postgres-event-store-1 psql -U postgres -d elixir_cqrs_event_store_dev -c "SELECT id, event_type, aggregate_id, event_version FROM events ORDER BY inserted_at DESC LIMIT 5;" 2>/dev/null || echo "Database not accessible"

# Test 4: Check snapshots
echo -e "\n\n4. Checking snapshots..."
docker exec elixir-cqrs-postgres-event-store-1 psql -U postgres -d elixir_cqrs_event_store_dev -c "SELECT id, aggregate_id, version FROM snapshots ORDER BY inserted_at DESC LIMIT 5;" 2>/dev/null || echo "Snapshots table not accessible"

echo -e "\n=== Test Complete ==="